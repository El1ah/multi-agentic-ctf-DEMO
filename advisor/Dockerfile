FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates bash \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash agent
COPY AGENTS.md /advisor/AGENTS.md
COPY watch.sh /opt/advisor/watch.sh
USER agent
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
ENV PATH="/home/agent/.local/bin:${PATH}"
WORKDIR /advisor
ENTRYPOINT ["bash", "/opt/advisor/watch.sh"]
