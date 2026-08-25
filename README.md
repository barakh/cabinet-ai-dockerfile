# Cabinet AI — Docker

Containerized [Cabinet](https://github.com/cabinetai/cabinet), the AI-first,
self-hosted knowledge base and startup OS. Everything lives as markdown files
on disk, runs on your own machine, and never leaves it.

This repo builds Cabinet's source into a Docker image and provides helpers to
run it. The app (Next.js) is served on port **4000** and the daemon
(WebSockets, scheduled jobs, agent execution) on port **4100**.

## Prerequisites

- Docker (with Compose).

## Build

```bash
./build.sh                 # builds cabinet:local from ../cabinet
./build.sh --no-cache      # rebuild without cache
./build.sh --tag mytag:1   # custom tag
```

Source is taken from `../cabinet` by default — override with `SRC_DIR`:

```bash
SRC_DIR=/path/to/cabinet ./build.sh
```

Or build directly:

```bash
docker build -t cabinet -f Dockerfile ../cabinet
```

## Run

### With the helper script

```bash
./run.sh                       # foreground, auto-restart
./run.sh --build --detach      # build first, then run in background
./run.sh --detach --rm         # background, remove container on exit
./run.sh --port 9000 --daemon-port 9100
```

Config via environment variables: `TAG`, `NAME`, `VOLUME`,
`KB_PASSWORD`, `CABINET_APP_ORIGIN`, `CABINET_PUBLIC_DAEMON_ORIGIN`.

### With Docker directly

```bash
docker run -d \
  --name cabinet \
  -p 4000:4000 \
  -p 4100:4100 \
  -v cabinet-data:/app/data \
  cabinet:local
```

### With Docker Compose

```bash
docker compose up -d
```

Data lives in the named `cabinet-data` volume by default. To use a local
folder instead:

```bash
CABINET_DATA_DIR=/home/me/cabinet-data docker compose up -d
```

Open http://localhost:4000.

## Installing Claude Code

Cabinet needs a supported AI provider CLI (Claude Code or Codex) to run
agents — it doesn't ship with one. Install Claude Code inside the running
container:

```bash
./run.sh --detach          # start the container first
./install-claude.sh        # installs Claude Code inside it
docker exec -it cabinet claude   # authenticate to finish setup
```

> **Note:** installs inside a running container are ephemeral and are lost
> when the container is recreated. To persist the install, commit the
> container (`docker commit cabinet cabinet:local`) or add the install command
> to the Dockerfile.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `KB_PASSWORD` | _(none)_ | Password to protect the UI. Leave unset for no auth. |
| `CABINET_APP_ORIGIN` | `http://127.0.0.1:4000` | Browser-visible app URL; set for LAN/VPS access. |
| `CABINET_PUBLIC_DAEMON_ORIGIN` | `http://127.0.0.1:4100` | Browser-visible daemon URL; set for LAN/VPS access. |
| `CABINET_DATA_DIR` | `/app/data` | Where Cabinet stores its data (cabinets, docs, sqlite db). |
| `CABINET_DAEMON_PORT` | `4100` | Daemon port (WebSockets / scheduler). |

Enable auth:

```bash
KB_PASSWORD=secret ./run.sh
# or
docker run -d -p 4000:4000 -p 4100:4100 -e KB_PASSWORD=secret cabinet:local
```

For access from another machine, point the browser at the reachable host and
configure both origins:

```bash
CABINET_APP_ORIGIN=http://192.168.1.10:4000 \
CABINET_PUBLIC_DAEMON_ORIGIN=ws://192.168.1.10:4100 \
./run.sh --detach
```

To disable anonymous usage telemetry:

```bash
docker run -d -e CABINET_TELEMETRY_DISABLED=1 cabinet:local
```

## Notes

- The image runs Cabinet from source (`npm run start` starts both the app and
  the daemon via `concurrently`), so the full `node_modules` is kept in the
  image.
- Native modules (`better-sqlite3`, `node-pty`) compile from source if the
  prebuilt binaries don't match the image's Node ABI; the image includes
  `build-essential`, `python3`, `make`, and `g++`.
- `git` is included because Cabinet auto-commits history for every save.
