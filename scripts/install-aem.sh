#!/usr/bin/env bash
# Canonical AEM VM installer (Phase 7): unpack the quickstart jar with the
# right runmodes, write the systemd unit, start AEM and wait for readiness.
# Used verbatim by the AWS user-data (embedded by Terraform templatefile) so
# there is exactly ONE copy of the install logic. The local Docker image uses
# a foreground entrypoint instead (container model), same jar + runmodes.
#
# Expects (env):
#   AEM_RUNMODE       author | publish                     (required)
#   AEM_PORT          4502 | 4503                          (required)
#   AEM_ENV_RUNMODE   dev | stage | prod                   (default: none)
#   AEM_HOME          install dir                          (default /opt/aem)
#   AEM_JVM_OPTS      JVM options                          (default G1GC 4g)
#   AEM_WAIT_READY    wait for login page 200              (default true)
# Requires: $AEM_HOME/cq-quickstart.jar and $AEM_HOME/license.properties
# already in place (the user-data fetches them from S3 first).
set -euo pipefail

AEM_HOME="${AEM_HOME:-/opt/aem}"
AEM_JVM_OPTS="${AEM_JVM_OPTS:--XX:+UseG1GC -Xms1024m -Xmx4096m -Djava.awt.headless=true}"
AEM_WAIT_READY="${AEM_WAIT_READY:-true}"
: "${AEM_RUNMODE:?AEM_RUNMODE is required (author|publish)}"
: "${AEM_PORT:?AEM_PORT is required}"

RUNMODES="${AEM_RUNMODE}${AEM_ENV_RUNMODE:+,${AEM_ENV_RUNMODE}}"
DATA_DIR="$AEM_HOME/crx-quickstart"

[ -f "$AEM_HOME/cq-quickstart.jar" ] || { echo "ERROR: $AEM_HOME/cq-quickstart.jar missing" >&2; exit 1; }
[ -f "$AEM_HOME/license.properties" ] || { echo "ERROR: $AEM_HOME/license.properties missing" >&2; exit 1; }

echo ">>> install-aem: runmodes=$RUNMODES port=$AEM_PORT home=$AEM_HOME"

id aem >/dev/null 2>&1 || useradd -r -d "$AEM_HOME" -s /sbin/nologin aem
chown -R aem:aem "$AEM_HOME"

# Unpack on first install only (crx-quickstart persists across replacements
# when it lives on the dedicated data volume).
if [ ! -d "$DATA_DIR/app" ]; then
  echo ">>> unpacking quickstart"
  (cd "$AEM_HOME" && runuser -u aem -- java -jar cq-quickstart.jar -unpack -r "$RUNMODES")
fi

cat > /etc/systemd/system/aem.service <<UNIT
[Unit]
Description=Adobe Experience Manager ($RUNMODES)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=aem
WorkingDirectory=$DATA_DIR
Environment=CQ_PORT=$AEM_PORT
Environment=CQ_RUNMODE=$RUNMODES
Environment=CQ_JVM_OPTS=$AEM_JVM_OPTS
ExecStart=$DATA_DIR/bin/start
ExecStop=$DATA_DIR/bin/stop
Restart=on-failure
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now aem.service

if [ "$AEM_WAIT_READY" = "true" ]; then
  echo ">>> waiting for AEM readiness on :$AEM_PORT (up to 20 min)"
  for i in $(seq 1 120); do
    if curl -sf -o /dev/null "http://localhost:$AEM_PORT/libs/granite/core/content/login.html"; then
      echo ">>> AEM ready after ~$((i * 10))s"
      exit 0
    fi
    sleep 10
  done
  echo "ERROR: AEM not ready after 20 min — check journalctl -u aem" >&2
  exit 1
fi
