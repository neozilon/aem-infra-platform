#!/usr/bin/env bash
# Security hardening baseline (Phase 7 / objective O5):
#   1. Rotate the admin password on Publish, then on Author
#   2. Re-point the Author->Publish replication agent transport credentials
#   3. Disable the default "author" demo user if present
#   4. Smoke checks: new password authenticates as admin, old one does not,
#      sensitive consoles are not anonymously accessible, and anonymous can
#      still read content on Publish (the public site must keep working)
# Idempotent: safe to re-run; also usable to rotate back (swap CURRENT/NEW).
#
# Implementation notes (verified against AEM 6.5 LTS):
#   - Password change = plain Sling POST of rep:password to the user's node.
#     The granite currentuser.changepassword.html and Sling userManager
#     endpoints are NOT available on 6.5 (the default POST servlet just
#     creates junk nodes and answers 200/201 — do not trust status codes).
#   - Auth checks MUST inspect the currentuser.json BODY: publish falls back
#     to 'anonymous' (HTTP 200) on wrong credentials instead of returning 401.
#
# Env:
#   AUTHOR_URL   (default http://localhost:4502)
#   PUBLISH_URL  (default http://localhost:4503)
#   CURRENT_ADMIN_PASS (default admin)
#   NEW_ADMIN_PASS     (required)
#   AGENT_NAMES  space-separated author replication agents (default "publish")
#   SMOKE_CONTENT_PATH  anonymous-read check on publish (default /content/aemdemo/us/en.html)
set -euo pipefail

AUTHOR_URL="${AUTHOR_URL:-http://localhost:4502}"
PUBLISH_URL="${PUBLISH_URL:-http://localhost:4503}"
CURRENT_ADMIN_PASS="${CURRENT_ADMIN_PASS:-admin}"
: "${NEW_ADMIN_PASS:?NEW_ADMIN_PASS is required}"
AGENT_NAMES="${AGENT_NAMES:-publish}"
SMOKE_CONTENT_PATH="${SMOKE_CONTENT_PATH:-/content/aemdemo/us/en.html}"

# Identity as reported by AEM for the given credentials ("admin", "anonymous",
# or "" when the request is rejected outright, e.g. 401 on author).
whoami_aem() { # $1 = base URL, $2 = password
  curl -s -u "admin:$2" "$1/libs/granite/security/currentuser.json" \
    | sed -n 's/.*"authorizableId":"\([^"]*\)".*/\1/p'
}

user_home() { # $1 = base URL, $2 = password -> the user's home path
  curl -s -u "admin:$2" "$1/libs/granite/security/currentuser.json" \
    | sed -n 's/.*"home":"\([^"]*\)".*/\1/p'
}

rotate_admin() { # $1 = base URL, $2 = label
  local url="$1" label="$2"
  if [ "$(whoami_aem "$url" "$NEW_ADMIN_PASS")" = "admin" ]; then
    echo "    $label: already rotated"
    return 0
  fi
  if [ "$(whoami_aem "$url" "$CURRENT_ADMIN_PASS")" != "admin" ]; then
    echo "    ERROR: $label: current admin password does not authenticate" >&2
    return 1
  fi
  local home
  home=$(user_home "$url" "$CURRENT_ADMIN_PASS")
  curl -sf -u "admin:$CURRENT_ADMIN_PASS" -X POST "$url$home" \
    -F "rep:password=$NEW_ADMIN_PASS" > /dev/null
  if [ "$(whoami_aem "$url" "$NEW_ADMIN_PASS")" = "admin" ]; then
    echo "    $label: admin password rotated"
  else
    echo "    ERROR: $label: rotation did not take effect" >&2
    return 1
  fi
}

echo ">>> 1/4 Rotate admin password (publish first, then author)"
rotate_admin "$PUBLISH_URL" "publish"
rotate_admin "$AUTHOR_URL" "author"

echo ">>> 2/4 Update replication agent transport credentials on Author"
for agent in $AGENT_NAMES; do
  curl -sf -u "admin:$NEW_ADMIN_PASS" \
    "$AUTHOR_URL/etc/replication/agents.author/$agent/jcr:content" \
    -F "transportUser=admin" \
    -F "transportPassword=$NEW_ADMIN_PASS" \
    > /dev/null
  RESULT=$(curl -sf -u "admin:$NEW_ADMIN_PASS" \
    "$AUTHOR_URL/etc/replication/agents.author/$agent/jcr:content.test.html" | grep -c "succeeded" || true)
  if [ "$RESULT" -ge 1 ]; then
    echo "    agent '$agent': transport updated, test SUCCEEDED"
  else
    echo "    ERROR: agent '$agent' test failed after rotation" >&2
    exit 1
  fi
done

echo ">>> 3/4 Disable default 'author' demo user (if present)"
for url in "$AUTHOR_URL" "$PUBLISH_URL"; do
  AUTHZ=$(curl -s -u "admin:$NEW_ADMIN_PASS" \
    "$url/bin/querybuilder.json?path=/home/users&type=rep:User&nodename=author&p.limit=1" \
    | sed -n 's/.*"path":"\([^"]*\)".*/\1/p' || true)
  if [ -n "$AUTHZ" ]; then
    curl -sf -u "admin:$NEW_ADMIN_PASS" -X POST "$url$AUTHZ.rw.html" \
      -F "disableUser=Disabled by harden.sh" > /dev/null \
      && echo "    $url: '$AUTHZ' disabled" \
      || echo "    WARNING: could not disable $AUTHZ on $url"
  else
    echo "    $url: no default 'author' user found"
  fi
done

echo ">>> 4/4 Smoke checks"
fail=0
ok() { echo "    OK   $1"; }
ko() { echo "    FAIL $1"; fail=1; }

if [ "$(whoami_aem "$AUTHOR_URL" "$NEW_ADMIN_PASS")" = "admin" ]; then
  ok "author: new password authenticates as admin"; else ko "author: new password does not authenticate"; fi
if [ "$(whoami_aem "$AUTHOR_URL" "$CURRENT_ADMIN_PASS")" != "admin" ]; then
  ok "author: old password no longer admin"; else ko "author: old password still authenticates as admin"; fi
if [ "$(whoami_aem "$PUBLISH_URL" "$CURRENT_ADMIN_PASS")" != "admin" ]; then
  ok "publish: old password no longer admin"; else ko "publish: old password still authenticates as admin"; fi

CRX_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHOR_URL/crx/de/index.jsp")
if [ "$CRX_CODE" != "200" ]; then
  ok "author: /crx/de not anonymous -> $CRX_CODE"; else ko "author: /crx/de anonymously accessible"; fi
CONSOLE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHOR_URL/system/console")
if [ "$CONSOLE_CODE" != "200" ]; then
  ok "author: /system/console not anonymous -> $CONSOLE_CODE"; else ko "author: /system/console anonymously accessible"; fi
CONTENT_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PUBLISH_URL$SMOKE_CONTENT_PATH")
if [ "$CONTENT_CODE" = "200" ]; then
  ok "publish: anonymous content read still works"; else ko "publish: anonymous content read broken -> $CONTENT_CODE"; fi

if [ "$fail" -ne 0 ]; then
  echo ">>> HARDENING COMPLETED WITH FAILURES" >&2
  exit 1
fi
echo ">>> Hardening complete"
