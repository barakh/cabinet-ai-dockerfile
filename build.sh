#!/usr/bin/env bash
# Build the Cabinet Docker image.
#
# Usage: ./build.sh [--no-cache] [--tag <name>]
set -euo pipefail

# Resolve the directory this script lives in, so it can be run from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults — override with env vars or flags.
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR/../cabinet}"         # cabinet source checkout
TAG="${TAG:-cabinet:local}"                          # image name:tag
CACHE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cache) CACHE_ARGS=(--no-cache) ;;
    --tag) TAG="${2:?--tag requires a value}"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ ! -f "$SRC_DIR/package.json" ]]; then
  echo "Error: cabinet source not found at $SRC_DIR (set SRC_DIR to override)." >&2
  exit 1
fi

echo "Building cabinet image '$TAG' from $SRC_DIR ..."
docker build "${CACHE_ARGS[@]}" \
  -t "$TAG" \
  -f "$SCRIPT_DIR/Dockerfile" \
  "$SRC_DIR"
echo "Done: $TAG"
