#!/usr/bin/env bash
# Install the Claude Code CLI inside the running Cabinet container.
#
# Cabinet needs a supported provider CLI (Claude Code or Codex) to run agents.
# This execs into the running container, installs Claude Code via:
#   curl -fsSL https://claude.ai/install.sh | bash
# then launches `claude login` so you can authenticate. The installer drops the
# binary at ~/.local/bin/claude; the exec shell is non-interactive (no .bashrc),
# so PATH is set explicitly here.
#
# Usage: ./install-claude.sh [--name <container>]
#
# NOTE: installs AND auth inside a running container are ephemeral — they vanish
# when the container is replaced or recreated. For persistence, either commit the
# container (`docker commit <name> <image>`) or mount a volume for /root/.claude.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME="${NAME:-cabinet}"   # container name, matches run.sh default

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:?--name requires a value}"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "Error: no running container named '$NAME'. Start Cabinet first, e.g. ./run.sh --detach" >&2
  exit 1
fi

echo "Installing Claude Code inside container '$NAME' ..."
docker exec -it "$NAME" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

echo
echo "Authenticating Claude Code inside container '$NAME' (follow the printed URL to log in) ..."
docker exec -it "$NAME" bash -lc 'export PATH="$HOME/.local/bin:$PATH"; claude login'

echo
echo "Claude Code installed and logged in."
echo "Remember: this does not persist across container rebuilds. Commit it to persist:"
echo "  docker commit $NAME ${IMAGE:-cabinet:local}"
