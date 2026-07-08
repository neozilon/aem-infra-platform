#!/usr/bin/env bash
# Starts AEM in the foreground. The quickstart jar unpacks crx-quickstart/ on
# first run and reuses it afterwards (persisted via the named volume).
set -euo pipefail

cd /opt/aem

echo ">>> Starting AEM: runmodes=${AEM_RUNMODE},${AEM_ENV_RUNMODE} port=${AEM_PORT}"
# -nofork keeps the JVM as PID-visible foreground process (required for Docker)
exec java ${AEM_JVM_OPTS} -jar cq-quickstart.jar \
  -r "${AEM_RUNMODE},${AEM_ENV_RUNMODE}" \
  -p "${AEM_PORT}" \
  -nointeractive -nobrowser -nofork
