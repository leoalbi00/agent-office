#!/usr/bin/env bash
# Starts the office in its container (deploy/render/Dockerfile), listening on 0.0.0.0:$PORT so
# Render's own HTTPS domain reaches it directly. Unlike deploy/container/start.sh there's no sshd
# and no tunnel: AGENT_OFFICE_PASSWORD is the only gate, so this script refuses to start without one
# rather than generate a password nobody could ever read back.
#
# Everything that has to outlive a restart or a redeploy lives on the disk at /data (render.yaml
# mounts it): /data/home is agentoffice's home — the office's data in ~/agent-office (password hash,
# accounts, floors, chat, per-account sign-ins), the projects in ~/workspace, Claude Code and its
# sign-in (~/.local, ~/.claude, ~/.claude.json), the GitHub CLI's (~/.config/gh), ~/.gitconfig.
set -euo pipefail
DATA=/data
RUN_USER=agentoffice
RUN_HOME=$DATA/home
RUN_PATH=$RUN_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PORT="${PORT:-4600}"

AS_USER=(setpriv --reuid=$RUN_USER --regid=$RUN_USER --init-groups
  env HOME=$RUN_HOME USER=$RUN_USER LOGNAME=$RUN_USER SHELL=/bin/bash PATH="$RUN_PATH")

say() { echo "agent-office-render: $*"; }

mountpoint -q $DATA || say "nothing is mounted on $DATA: the office forgets everything when this container goes"

if [[ -z "${AGENT_OFFICE_PASSWORD:-}" ]]; then
  say "AGENT_OFFICE_PASSWORD isn't set. This office is directly on the internet with no SSH gate in front of it, so there's no safe way to generate a password here and show it to you later. Set AGENT_OFFICE_PASSWORD in Render's dashboard (Environment) and redeploy."
  exit 1
fi

install -d -m 755 -o $RUN_USER -g $RUN_USER $RUN_HOME
for f in .bashrc .profile; do
  [[ -e $RUN_HOME/$f ]] || install -m 644 -o $RUN_USER -g $RUN_USER /etc/skel/$f $RUN_HOME/$f
done
cd $RUN_HOME

if [[ ! -x $RUN_HOME/.local/bin/claude ]]; then
  say "installing Claude Code in $RUN_HOME/.local (first start)"
  "${AS_USER[@]}" bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null ||
    say "couldn't install Claude Code; it's tried again at the next start"
fi
"${AS_USER[@]}" mkdir -p $RUN_HOME/workspace
# Once: after that, the folder is the admins' to move in ⚙️ Settings.
if [[ ! -f $RUN_HOME/agent-office/.agent-office/projects-folder.json ]]; then
  "${AS_USER[@]}" node /opt/agent-office/bin/agent-office.js setup --projects $RUN_HOME/workspace </dev/null
fi

say "listening on 0.0.0.0:$PORT, reachable at this service's Render URL, gated only by the office password"
exec "${AS_USER[@]}" node /opt/agent-office/bin/agent-office.js --host 0.0.0.0 --port "$PORT" --trust-proxy --no-open
