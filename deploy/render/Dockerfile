# Agent Office in a container for Render (../../render.yaml): a public web service, unlike
# deploy/container/Dockerfile, which is SSH-only. Render terminates HTTPS on its own domain and
# forwards to $PORT; the office listens on 0.0.0.0:$PORT directly, with no SSH layer in front of
# it, so AGENT_OFFICE_PASSWORD is the only thing standing between this container and the internet.
#
# render.yaml mounts a persistent disk at /data: everything that has to outlive a restart or a
# redeploy is there (deploy/render/start.sh).
#
# Build it from the repository root: docker build -f deploy/render/Dockerfile .
FROM node:22-bookworm-slim AS build
WORKDIR /opt/agent-office
COPY package.json package-lock.json ./
# No install scripts: `prepare` would build before the sources are here.
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY . .
RUN chmod 755 bin/*.js deploy/render/*.sh \
  && npm run build && npm prune --omit=dev --ignore-scripts --no-audit --no-fund

FROM node:22-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
# tini to reap what workers leave behind, `ss` (iproute2) for the office to find the web servers
# workers start, and what workers need: git, the GitHub CLI (from GitHub's own apt repo, like
# deploy/provision.sh) and build tools.
RUN apt-get update \
  && apt-get install -y --no-install-recommends tini procps iproute2 ca-certificates curl git less build-essential python3 \
  && install -d -m 755 /etc/apt/keyrings \
  && curl -fsSLo /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    >/etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*
# The office runs as agentoffice, like on a server set up by provision.sh: node's own user (uid 1000),
# renamed, with its home on the disk.
RUN usermod --login agentoffice --home /data/home --shell /bin/bash --password '*' node \
  && groupmod --new-name agentoffice node \
  && rm -rf /home/node
COPY --from=build /opt/agent-office /opt/agent-office
EXPOSE 4600
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/agent-office/deploy/render/start.sh"]
