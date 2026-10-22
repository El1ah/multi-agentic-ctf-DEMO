FROM kalilinux/kali-rolling

# seclists займає ~2 ГБ. Без місця на диску: docker compose build --build-arg WITH_SECLISTS=0
ARG WITH_SECLISTS=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap ffuf gobuster sqlmap whatweb netcat-openbsd \
    openvpn iptables iproute2 dnsutils curl jq git \
    python3 python3-pip gdb asciinema ca-certificates \
    build-essential cmake pkg-config \
 && if [ "$WITH_SECLISTS" = "1" ]; then apt-get install -y --no-install-recommends seclists; fi \
 && pip3 install --break-system-packages pwntools \
 && rm -rf /var/lib/apt/lists/* /root/.cache

RUN useradd -m -u 1000 -s /bin/bash agent
USER agent
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/agent/.local/bin:${PATH}"
USER root

COPY scripts/entrypoint.sh scripts/firewall.sh /opt/lab/
RUN chmod 755 /opt/lab/*.sh
ENTRYPOINT ["/opt/lab/entrypoint.sh"]
