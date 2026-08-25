#!/usr/bin/env bash
# Run the Cabinet Docker container.
#
# Usage: ./run.sh [--name <name>] [--port <app>] [--daemon-port <daemon>] [--detach]
#        ./run.sh --build                # build the image first, then run
#        ./run.sh --rm                   # remove the container when it exits
#
# Common overrides (set as env before running, or edit below):
#   TAG, NAME, VOLUME, KB_PASSWORD, CABINET_APP_ORIGIN, CABINET_PUBLIC_DAEMON_ORIGIN
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TAG="${TAG:-cabinet:local}"
NAME="${NAME:-cabinet}"
VOLUME="${VOLUME:-cabinet-data}"        # docker volume for /app/data
APP_PORT="${APP_PORT:-4000}"            # host port -> app
DAEMON_PORT="${DAEMON_PORT:-4100}"      # host port -> daemon

BUILD=0
DETACH=0
RM=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD=1 ;;
    --detach|-d) DETACH=1 ;;
    --rm) RM=1 ;;
    --name) NAME="${2:?--name requires a value}"; shift ;;
    --port) APP_PORT="${2:?--port requires a value}"; shift ;;
    --daemon-port) DAEMON_PORT="${2:?--daemon-port requires a value}"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ "$BUILD" == "1" ]]; then
  "$SCRIPT_DIR/build.sh"
fi

docker_args=(
  --name "$NAME"
  -p "$APP_PORT:4000"
  -p "$DAEMON_PORT:4100"
  -v "$VOLUME:/app/data"
)

# --restart and --rm are mutually exclusive; default to auto-restart, allow --rm.
if [[ "$RM" == "1" ]]; then
  docker_args+=(--rm)
else
  docker_args+=(--restart unless-stopped)
fi

if [[ "$DETACH" == "1" ]]; then
  docker_args+=(-d)
fi

# Optional auth (enable by setting KB_PASSWORD, e.g. KB_PASSWORD=secret ./run.sh).
if [[ -n "${KB_PASSWORD:-}" ]]; then
  docker_args+=(-e "KB_PASSWORD=$KB_PASSWORD")
fi

# Optional origin overrides for LAN/VPS access.
if [[ -n "${CABINET_APP_ORIGIN:-}" ]]; then
  docker_args+=(-e "CABINET_APP_ORIGIN=$CABINET_APP_ORIGIN")
fi
if [[ -n "${CABINET_PUBLIC_DAEMON_ORIGIN:-}" ]]; then
  docker_args+=(-e "CABINET_PUBLIC_DAEMON_ORIGIN=$CABINET_PUBLIC_DAEMON_ORIGIN")
fi

docker run "${docker_args[@]}" "$TAG"

if [[ "$DETACH" == "1" ]]; then
  echo "Cabinet started in container '$NAME'."
  echo "  App:    http://localhost:$APP_PORT"
  echo "  Daemon: port $DAEMON_PORT (internal, for websockets/scheduler)"
else
  echo "Cabinet stopped."
fi
