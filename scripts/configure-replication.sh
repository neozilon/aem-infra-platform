#!/usr/bin/env bash
# Configures AEM replication end-to-end (Phase 2/7):
#   1. Author → Publish replication agent (content activation)
#   2. Publish → Dispatcher flush agent (cache invalidation)
# Idempotent: safe to re-run. Works locally and on AWS via env overrides.
set -euo pipefail

# --- Endpoints as reachable from THIS script (defaults = local stack) ------
AUTHOR_URL="${AUTHOR_URL:-http://localhost:4502}"
PUBLISH_URL="${PUBLISH_URL:-http://localhost:4503}"
# --- Endpoints as reachable INSIDE the network (compose service names) -----
PUBLISH_INTERNAL="${PUBLISH_INTERNAL:-http://publish:4503}"
DISPATCHER_INTERNAL="${DISPATCHER_INTERNAL:-http://dispatcher:80}"
# --- Credentials ------------------------------------------------------------
AUTHOR_CREDS="${AUTHOR_CREDS:-admin:admin}"
PUBLISH_CREDS="${PUBLISH_CREDS:-admin:admin}"
PUBLISH_USER_ON_PUBLISH="${PUBLISH_USER_ON_PUBLISH:-admin}"
PUBLISH_PASS_ON_PUBLISH="${PUBLISH_PASS_ON_PUBLISH:-admin}"
# --- Agent name on Author (pair 0 uses the built-in "publish" agent; extra
#     pairs get their own agent, e.g. AGENT_NAME=publish1) --------------------
AGENT_NAME="${AGENT_NAME:-publish}"

echo ">>> 1/3 Configure Author replication agent '${AGENT_NAME}' → ${PUBLISH_INTERNAL}"
# Create the agent page when it doesn't exist (any non-default agent).
if ! curl -sf -u "${AUTHOR_CREDS}" -o /dev/null \
  "${AUTHOR_URL}/etc/replication/agents.author/${AGENT_NAME}.json"; then
  curl -sf -u "${AUTHOR_CREDS}" \
    "${AUTHOR_URL}/etc/replication/agents.author/${AGENT_NAME}" \
    -F "jcr:primaryType=cq:Page" > /dev/null
fi
curl -sf -u "${AUTHOR_CREDS}" \
  "${AUTHOR_URL}/etc/replication/agents.author/${AGENT_NAME}/jcr:content" \
  -F "jcr:primaryType=nt:unstructured" \
  -F "jcr:title=Replication ${AGENT_NAME}" \
  -F "sling:resourceType=cq/replication/components/agent" \
  -F "cq:template=/libs/cq/replication/templates/agent" \
  -F "serializationType=durbo" \
  -F "retryDelay=60000" \
  -F "enabled=true" \
  -F "transportUri=${PUBLISH_INTERNAL}/bin/receive?sling:authRequestLogin=1" \
  -F "transportUser=${PUBLISH_USER_ON_PUBLISH}" \
  -F "transportPassword=${PUBLISH_PASS_ON_PUBLISH}" \
  -F "protocolHTTPSExpired=false" \
  > /dev/null
echo "    OK"

echo ">>> 2/3 Create/Update flush agent on Publish → ${DISPATCHER_INTERNAL}"
curl -sf -u "${PUBLISH_CREDS}" \
  "${PUBLISH_URL}/etc/replication/agents.publish/flush" \
  -F "jcr:primaryType=cq:Page" > /dev/null 2>&1 || true   # node may exist
curl -sf -u "${PUBLISH_CREDS}" \
  "${PUBLISH_URL}/etc/replication/agents.publish/flush/jcr:content" \
  -F "jcr:primaryType=nt:unstructured" \
  -F "jcr:title=Dispatcher Flush" \
  -F "sling:resourceType=cq/replication/components/agent" \
  -F "cq:template=/libs/cq/replication/templates/agent" \
  -F "transportUri=${DISPATCHER_INTERNAL}/dispatcher/invalidate.cache" \
  -F "protocolHTTPHeaders=CQ-Action:{action}" \
  -F "protocolHTTPHeaders=CQ-Handle:{path}" \
  -F "protocolHTTPHeaders=CQ-Path:{path}" \
  -F "protocolHTTPHeaders@TypeHint=String[]" \
  -F "protocolHTTPMethod=GET" \
  -F "serializationType=flush" \
  -F "noVersioning=true" \
  -F "triggerReceive=true" \
  -F "triggerSpecific=true" \
  -F "enabled=true" \
  > /dev/null
echo "    OK"

echo ">>> 3/3 Verify: test author→publish agent connection"
RESULT=$(curl -sf -u "${AUTHOR_CREDS}" \
  "${AUTHOR_URL}/etc/replication/agents.author/${AGENT_NAME}/jcr:content.test.html" | grep -c "succeeded" || true)
if [ "${RESULT}" -ge 1 ]; then
  echo "    Replication test SUCCEEDED"
else
  echo "    WARNING: replication test did not report success — check ${AUTHOR_URL}/etc/replication/agents.author/${AGENT_NAME}.html"
  exit 1
fi
