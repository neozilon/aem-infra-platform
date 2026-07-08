# Shared image for AEM Author and Publish (role selected via AEM_RUNMODE)
# Build context must be the repository root (needs binaries/).
FROM eclipse-temurin:21-jdk-jammy

RUN useradd -r -m -d /opt/aem aem && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/aem
COPY --chown=aem:aem binaries/cq-quickstart-6.6.0.jar ./cq-quickstart.jar
COPY --chown=aem:aem binaries/license.properties ./license.properties
COPY --chown=aem:aem docker/aem/entrypoint.sh /entrypoint.sh
# Pre-create the volume mountpoint owned by aem, otherwise Docker creates it
# root-owned and the unpack fails (AEM then tries to open a GUI error dialog).
RUN chmod +x /entrypoint.sh \
    && mkdir -p /opt/aem/crx-quickstart \
    && chown aem:aem /opt/aem/crx-quickstart

USER aem

# Role + environment runmodes and port come from compose
ENV AEM_RUNMODE=author \
    AEM_ENV_RUNMODE=dev \
    AEM_PORT=4502 \
    AEM_JVM_OPTS="-XX:+UseG1GC -Xms1024m -Xmx4096m -Djava.awt.headless=true"

VOLUME ["/opt/aem/crx-quickstart"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=600s --retries=10 \
  CMD curl -sf "http://localhost:${AEM_PORT}/libs/granite/core/content/login.html" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
