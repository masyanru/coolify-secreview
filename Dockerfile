# coolify-secreview: контейнер-"жертва" для проверки container -> host/network escape
#
# Режимы (через env в Coolify):
#   (default)         - bind shell (socat, pty) на 0.0.0.0:${BIND_PORT:-4444}
#   RHOST + RPORT     - reverse shell loop на указанный хост:порт
#   BIND_PORT=0       - idle: sleep infinity (shell через веб-терминал Coolify)
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
RUN chmod +x /entrypoint.sh /opt/enum.sh

ENTRYPOINT ["/entrypoint.sh"]
