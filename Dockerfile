# Phase 1 discussion summary: single-stage node:22, rely on `npm run start`
# to launch both the Next.js app and the Cabinet daemon, keep auth unset by
# default and document it, persist data under /app/data.

# Use the Debian-based node LTS image so native modules (better-sqlite3,
# node-pty) have a matching toolchain available for any needed rebuilds.
FROM node:22-bookworm-slim

# Runtime prerequisites: git is required for Cabinet's auto-commit history,
# ca-certificates for HTTPS, procps for utilities, and build-essential + python3
# + make + g++ so better-sqlite3 / node-pty can compile from source if their
# prebuilt binaries don't match the image's Node ABI.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    procps \
    curl \
    build-essential \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the source tree. The package.json `postinstall` hook (scripts/postinstall.mjs)
# must run during `npm ci` and copies latex.js assets into public/, so the whole
# tree needs to be present before dependencies are installed. The cabinet repo's
# .dockerignore skips node_modules, .next, data, git, etc.
COPY . .

# Install ALL dependencies (including devDependencies). Cabinet runs the daemon
# via tsx from source at runtime (`npm run start` -> `tsx server/cabinet-daemon.ts`),
# so the full node_modules must remain present rather than the standalone-only path.
# The postinstall hook rebuilds native modules if the prebuild ABI mismatches.
RUN npm ci

# Prebuild the Next.js production bundle. `next build` runs the postbuild hook
# (copy-standalone-assets.mjs) which copies static assets so pages render.
RUN npm run build

# Cabinet keeps user-owned content (cabinets, docs, conversations, sqlite db)
# in the data directory. Persist it on a volume so it survives container
# rebuilds/removal.
ENV CABINET_DATA_DIR=/app/data
VOLUME /app/data

# Map the app's bind port. Cabinet app code defaults to port 4000
# (getAppPort falls back to 4000) but `next start` binds to process.env.PORT
# (Next's default is 3000 otherwise), so pin PORT and CABINET_APP_PORT to 4000.
# The daemon listens on CABINET_DAEMON_PORT (default 4100).
ENV PORT=4000 \
    CABINET_APP_PORT=4000 \
    CABINET_DAEMON_PORT=4100

# Both processes use loopback as their default origin, which is fine for
# local access. Override with docker -e for LAN/VPS deployments:
#   CABINET_APP_ORIGIN=http://<host>:4000
#   CABINET_PUBLIC_DAEMON_ORIGIN=ws://<host>:4100
EXPOSE 4000 4100

# `npm run start` launches both processes via concurrently:
#   start:next   -> next start   (app on port 4000)
#   start:daemon -> tsx server/cabinet-daemon.ts (daemon on port 4100)
CMD ["npm", "run", "start"]
