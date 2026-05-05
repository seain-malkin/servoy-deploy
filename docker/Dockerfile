# syntax=docker/dockerfile:1
#
# Servoy Test Environment
#
# Build (from repo root):
#   docker build -f docker/Dockerfile -t servoy-test .
#
# Run:
#   docker run --rm \
#     -e REPO_URL=https://github.com/org/repo \
#     -e REPO_BRANCH=main \
#     -e PROJECT_NAME=MyServoyApp \
#     [-e GITHUB_TOKEN=ghp_xxx]  # only needed for private repos
#     servoy-test

FROM debian:bookworm-slim

# ── System dependencies ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless \
        curl \
        wget \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# ── Tomcat 10 ────────────────────────────────────────────────────────────────
ARG TOMCAT_VERSION=10.1.54
ENV CATALINA_HOME=/opt/tomcat

RUN set -eux; \
    wget -q "https://downloads.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
         -O /tmp/tomcat.tar.gz; \
    mkdir -p "${CATALINA_HOME}"; \
    tar -xzf /tmp/tomcat.tar.gz -C "${CATALINA_HOME}" --strip-components=1; \
    rm /tmp/tomcat.tar.gz; \
    # Remove default ROOT webapp so our WAR is deployed as root
    rm -rf "${CATALINA_HOME}/webapps/ROOT" "${CATALINA_HOME}/webapps/ROOT.war"; \
    chmod +x "${CATALINA_HOME}/bin"/*.sh

COPY docker/tomcat/setenv.sh "${CATALINA_HOME}/bin/setenv.sh"
RUN sed -i 's/\r$//' "${CATALINA_HOME}/bin/setenv.sh" && chmod +x "${CATALINA_HOME}/bin/setenv.sh"

ENV PATH="${CATALINA_HOME}/bin:${PATH}"

# ── Servoy ───────────────────────────────────────────────────────────────────
ENV SERVOY_HOME=/opt/servoy

COPY artificats/servoy_linux.4046.tar.gz /tmp/servoy.tar.gz
RUN set -eux; \
    mkdir -p "${SERVOY_HOME}"; \
    tar -xzf /tmp/servoy.tar.gz -C "${SERVOY_HOME}"; \
    rm /tmp/servoy.tar.gz; \
    find "${SERVOY_HOME}" -name "*.sh" -exec chmod +x {} \;

# ── Entrypoint ───────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
