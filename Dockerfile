FROM ghcr.io/nextlevelbuilder/goclaw:v3.11.3 AS goclaw

FROM node:24.15.0-bookworm-slim

COPY --from=goclaw --chown=1000:1000 /app /app

RUN \
# for mscorefonts
    sed -i 's/Components: main/Components: main contrib/g' /etc/apt/sources.list.d/debian.sources && \
    apt update && \
    apt install -y curl git git-lfs ca-certificates build-essential && \
# install cloudflared
    mkdir -p --mode=0755 /usr/share/keyrings && \
    curl -fsSLo /usr/share/keyrings/cloudflare-main.gpg https://pkg.cloudflare.com/cloudflare-main.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list && \
    apt update && \
    apt install -y cloudflared && \
    curl -fsSLo /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux64 && \
    chmod +x /usr/local/bin/jq && \
    curl -fsSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.53.2/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq && \
    apt install -y --no-install-recommends \
        fonts-dejavu-core \
        fonts-dejavu-extra \
        fonts-freefont-ttf \
        fonts-ipafont-gothic \
        fonts-kacst \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        fonts-thai-tlwg \
        fonts-wqy-microhei \
        fonts-wqy-zenhei \
        ttf-mscorefonts-installer \
        && \
    fc-cache -f -v && \
    npx -y playwright@latest install-deps && \
    npx -y playwright@latest install chrome && \
# copy from https://github.com/nextlevelbuilder/goclaw/blob/v3.11.3/Dockerfile
    curl -fsSLo /tmp/requirements-base.txt   https://raw.githubusercontent.com/nextlevelbuilder/goclaw/refs/tags/v3.11.3/docker/requirements-base.txt && \
    curl -fsSLo /tmp/requirements-skills.txt https://raw.githubusercontent.com/nextlevelbuilder/goclaw/refs/tags/v3.11.3/docker/requirements-skills.txt && \
    apt install --no-install-recommends -y python3 python3-pip pandoc gh poppler-utils && \
    pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements-base.txt -r /tmp/requirements-skills.txt && \
    npm install -g --cache /tmp/npm-cache docx@^9.6.1 pptxgenjs@^4.0.1 && \
# copy end
# move node home to /app
    usermod -d /app node && \
    apt clean && apt autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/*

USER node

# Default environment
ENV GOCLAW_CONFIG=/app/config.json \
    GOCLAW_WORKSPACE=/app/workspace \
    GOCLAW_DATA_DIR=/app/data \
    GOCLAW_SKILLS_DIR=/app/skills \
    GOCLAW_MIGRATIONS_DIR=/app/migrations \
    GOCLAW_HOST=0.0.0.0 \
    GOCLAW_PORT=18790 \
    HOMEBREW_PREFIX="/app/homebrew" \
    HOMEBREW_CELLAR="/app/homebrew/Cellar" \
    HOMEBREW_REPOSITORY="/app/homebrew" \
    HOMEBREW_NO_ENV_HINTS=1 \
    NPM_CONFIG_PREFIX="/home/node/.npm-packages" \
    PATH="/app/homebrew/bin:/app/homebrew/sbin:/home/node/.npm-packages/bin:$PATH"

RUN \
# install goclaw
    curl -fsSL https://github.com/nextlevelbuilder/goclaw/releases/download/v3.11.3/goclaw-3.11.3-linux-amd64.tar.gz | tar -C /app -xvzf - && \
# install homebrew
    git clone https://github.com/Homebrew/brew /app/homebrew && \
    brew install gogcli

EXPOSE 18790

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:18790/health || exit 1

ENTRYPOINT ["/goclaw/docker-entrypoint.sh"]
CMD ["serve"]
