# Copilot Instructions

## Repository Purpose

This repo provides a Docker-based CI environment for deploying and smoke-testing [Servoy](https://servoy.com/) applications. It is **not** the Servoy application code itself — it builds a reusable Docker image that, at runtime, clones an external Servoy project, exports a WAR file, deploys it to Tomcat, and verifies the deployment via health check.

## Architecture

```
artificats/servoy_linux.4046.tar.gz   ← Servoy installer baked into the image at build time
docker/
  Dockerfile         ← Builds image: Debian + Java 17 + Tomcat 10 + Servoy
  entrypoint.sh      ← Runtime: clone → WAR export → Tomcat deploy → health check
  tomcat/setenv.sh   ← JVM flags for Tomcat (adjust -Xmx for runner memory)
.github/workflows/
  servoy-test.yml    ← CI: builds image, runs container against an external Servoy project repo
```

**Image build context is always the repo root**, not the `docker/` directory:
```sh
docker build -f docker/Dockerfile -t servoy-test .
```

The Servoy installer (`artificats/servoy_linux.4046.tar.gz`) is copied directly into the image — updating Servoy means replacing this file and rebuilding.

## Build & Run

**Build the Docker image:**
```sh
docker build -f docker/Dockerfile -t servoy-test .
```

**Run the container** (required vars: `REPO_URL`, `PROJECT_NAME`):
```sh
docker run --rm \
  -e REPO_URL=https://github.com/org/repo \
  -e PROJECT_NAME=MyServoyApp \
  [-e REPO_BRANCH=main] \
  [-e GITHUB_TOKEN=ghp_xxx] \
  servoy-test
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `REPO_URL` | ✅ | — | Git URL of the Servoy project to test |
| `PROJECT_NAME` | ✅ | — | Servoy project name to export as WAR |
| `REPO_BRANCH` | | `main` | Branch to clone |
| `GITHUB_TOKEN` | | — | Token for private repos |
| `HEALTH_CHECK_URL` | | `http://localhost:8080/` | URL polled after Tomcat starts |
| `HEALTH_CHECK_RETRIES` | | `30` | Max poll attempts |
| `HEALTH_CHECK_DELAY` | | `5` | Seconds between polls |
| `WAR_EXTRA_ARGS` | | — | Extra args passed to `war_export.sh` |
| `WORKSPACE_DIR` | | `/workspace` | Where to clone the repo inside the container |
| `MYSQL_ROOT_PASSWORD` | | *(no password)* | Root password set after MySQL init |
| `MYSQL_DATABASE` | | — | Database to create on startup |
| `MYSQL_USER` | | — | App user to create (requires `MYSQL_DATABASE`) |
| `MYSQL_PASSWORD` | | — | Password for `MYSQL_USER` |

## GitHub Actions CI

The workflow (`.github/workflows/servoy-test.yml`) triggers on pushes/PRs to `feature/**` branches and on `workflow_dispatch`.

**Required GitHub Actions configuration** (set in repo/org settings):
- **Variables**: `SERVOY_PROJECT_REPO_URL`, `SERVOY_PROJECT_NAME`
- **Secret**: `SERVOY_REPO_TOKEN` (only needed for private Servoy project repos)

## Key Conventions

- **`artificats/`** — note the intentional (or legacy) misspelling; the cache key in the workflow uses `artificats/**`, so any rename must be updated in both the Dockerfile and workflow.
- The `entrypoint.sh` uses POSIX `sh` (not `bash`) — avoid bashisms.
- Line-ending normalisation (`sed -i 's/\r$//'`) is applied to shell scripts in the Dockerfile to handle Windows-authored files.
- The WAR is always deployed as Tomcat's `ROOT` webapp (`webapps/ROOT.war`), replacing the default ROOT.
- The CI workflow uploads Tomcat logs as an artifact on failure, but only if a volume is mounted — see the comment in `servoy-test.yml` referencing `docs/advanced-logging.md`.
