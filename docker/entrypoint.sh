#!/bin/sh
# entrypoint.sh — clone → build WAR → deploy → start Tomcat → health check → exit
#
# Required environment variables:
#   REPO_URL      Git URL of the Servoy project (e.g. https://github.com/org/repo)
#   PROJECT_NAME  Servoy application/project name to export as a WAR
#
# Optional environment variables:
#   REPO_BRANCH          Branch to clone (default: main)
#   GITHUB_TOKEN         Personal access token for private repos
#   HEALTH_CHECK_URL     URL to poll after Tomcat starts (default: http://localhost:8080/)
#   HEALTH_CHECK_RETRIES Number of times to retry the health check (default: 30)
#   HEALTH_CHECK_DELAY   Seconds between retries (default: 5)
#   WAR_EXTRA_ARGS       Additional arguments to pass to war_export.sh
#   WORKSPACE_DIR        Where to clone the repo (default: /workspace)

set -e

# ── Defaults ─────────────────────────────────────────────────────────────────
REPO_BRANCH="${REPO_BRANCH:-main}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:8080/}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-30}"
HEALTH_CHECK_DELAY="${HEALTH_CHECK_DELAY:-5}"
WAR_OUTPUT="/tmp/servoy-app.war"
WAR_EXPORTER="${SERVOY_HOME}/developer/exporter/war_export.sh"

# ── Validate required vars ────────────────────────────────────────────────────
if [ -z "${REPO_URL}" ]; then
  echo "ERROR: REPO_URL is required." >&2
  exit 1
fi
if [ -z "${PROJECT_NAME}" ]; then
  echo "ERROR: PROJECT_NAME is required." >&2
  exit 1
fi

echo "==> Cloning ${REPO_URL} (branch: ${REPO_BRANCH})..."

# Inject token into HTTPS URL for private repos
CLONE_URL="${REPO_URL}"
if [ -n "${GITHUB_TOKEN}" ]; then
  # Strip any existing credentials, then inject the token
  CLONE_URL=$(echo "${REPO_URL}" | sed 's|https://|https://x-access-token:'"${GITHUB_TOKEN}"'@|')
fi

rm -rf "${WORKSPACE_DIR}"
git clone --depth=1 --branch "${REPO_BRANCH}" "${CLONE_URL}" "${WORKSPACE_DIR}"
echo "==> Clone complete."

# ── Show war_export.sh usage for diagnostics ─────────────────────────────────
echo "==> war_export.sh usage:"
"${WAR_EXPORTER}" 2>&1 || true   # exits non-zero when called with no args — that's expected

# ── Build the WAR ─────────────────────────────────────────────────────────────
echo "==> Building WAR for project '${PROJECT_NAME}'..."
"${WAR_EXPORTER}" \
  -workspace "${WORKSPACE_DIR}" \
  -project_name "${PROJECT_NAME}" \
  -output "${WAR_OUTPUT}" \
  ${WAR_EXTRA_ARGS:-}

echo "==> WAR built: ${WAR_OUTPUT}"

# ── Deploy to Tomcat ──────────────────────────────────────────────────────────
echo "==> Deploying WAR to Tomcat..."
cp "${WAR_OUTPUT}" "${CATALINA_HOME}/webapps/ROOT.war"

# ── Start Tomcat ──────────────────────────────────────────────────────────────
echo "==> Starting Tomcat..."
"${CATALINA_HOME}/bin/catalina.sh" start

# ── Wait for Tomcat to be ready ───────────────────────────────────────────────
echo "==> Waiting for Tomcat at ${HEALTH_CHECK_URL} ..."
i=0
while [ "${i}" -lt "${HEALTH_CHECK_RETRIES}" ]; do
  if curl -sf -o /dev/null "${HEALTH_CHECK_URL}"; then
    echo "==> Tomcat is up."
    break
  fi
  i=$((i + 1))
  echo "    Attempt ${i}/${HEALTH_CHECK_RETRIES} — not ready yet, waiting ${HEALTH_CHECK_DELAY}s..."
  sleep "${HEALTH_CHECK_DELAY}"
done

if [ "${i}" -ge "${HEALTH_CHECK_RETRIES}" ]; then
  echo "ERROR: Tomcat did not become ready after $((HEALTH_CHECK_RETRIES * HEALTH_CHECK_DELAY))s." >&2
  echo "==> Tomcat logs:" >&2
  cat "${CATALINA_HOME}/logs/catalina.out" >&2
  exit 1
fi

# ── Health check ─────────────────────────────────────────────────────────────
echo "==> Running health check against ${HEALTH_CHECK_URL} ..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_CHECK_URL}")

if [ "${HTTP_STATUS}" -ge 200 ] && [ "${HTTP_STATUS}" -lt 400 ]; then
  echo "==> Health check passed (HTTP ${HTTP_STATUS})."
  exit 0
else
  echo "ERROR: Health check failed (HTTP ${HTTP_STATUS})." >&2
  echo "==> Tomcat logs:" >&2
  cat "${CATALINA_HOME}/logs/catalina.out" >&2
  exit 1
fi
