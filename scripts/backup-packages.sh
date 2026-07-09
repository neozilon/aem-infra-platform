#!/usr/bin/env bash
# Tier-2 backup (Phase 7 / PLAN §8): export a content package from AEM and
# store it (optionally) in the versioned S3 backup bucket.
#   1. Create/refresh a package definition with the content filter
#   2. Build it via the CRX Package Manager API
#   3. Download the zip locally
#   4. Upload to s3://$BACKUP_BUCKET/packages/ when configured (else keep local)
#
# Env:
#   AEM_URL        instance to back up            (default http://localhost:4502)
#   AEM_CREDS      user:pass                      (default admin:admin)
#   FILTER_ROOT    content root to export         (default /content/aemdemo)
#   PKG_GROUP      package group                  (default backups)
#   PKG_NAME       package name                   (default content-backup)
#   OUT_DIR        local output directory         (default ./backups)
#   BACKUP_BUCKET  S3 bucket name; empty = local only
set -euo pipefail

AEM_URL="${AEM_URL:-http://localhost:4502}"
AEM_CREDS="${AEM_CREDS:-admin:admin}"
FILTER_ROOT="${FILTER_ROOT:-/content/aemdemo}"
PKG_GROUP="${PKG_GROUP:-backups}"
PKG_NAME="${PKG_NAME:-content-backup}"
OUT_DIR="${OUT_DIR:-./backups}"
BACKUP_BUCKET="${BACKUP_BUCKET:-}"

PKG_PATH="/etc/packages/${PKG_GROUP}/${PKG_NAME}.zip"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT_FILE="${OUT_DIR}/${PKG_NAME}-${STAMP}.zip"

echo ">>> 1/4 Create/refresh package ${PKG_GROUP}/${PKG_NAME} (filter: ${FILTER_ROOT})"
curl -sf -u "${AEM_CREDS}" -X POST \
  "${AEM_URL}/crx/packmgr/service/.json${PKG_PATH}?cmd=create" \
  -d "packageName=${PKG_NAME}" -d "groupName=${PKG_GROUP}" \
  > /dev/null 2>&1 || true   # already exists
curl -sf -u "${AEM_CREDS}" -X POST "${AEM_URL}/crx/packmgr/update.jsp" \
  -F "path=${PKG_PATH}" \
  -F "packageName=${PKG_NAME}" \
  -F "groupName=${PKG_GROUP}" \
  -F "version=" \
  -F "filter=[{\"root\":\"${FILTER_ROOT}\",\"rules\":[]}]" \
  | grep -q '"success":true' || { echo "ERROR: filter update failed" >&2; exit 1; }
echo "    OK"

echo ">>> 2/4 Build package"
curl -sf -u "${AEM_CREDS}" -X POST \
  "${AEM_URL}/crx/packmgr/service/.json${PKG_PATH}?cmd=build" \
  | grep -q '"success":true' || { echo "ERROR: build failed" >&2; exit 1; }
echo "    OK"

echo ">>> 3/4 Download to ${OUT_FILE}"
mkdir -p "${OUT_DIR}"
curl -sf -u "${AEM_CREDS}" -o "${OUT_FILE}" "${AEM_URL}${PKG_PATH}"
SIZE=$(du -h "${OUT_FILE}" | cut -f1)
unzip -t "${OUT_FILE}" > /dev/null || { echo "ERROR: downloaded package is not a valid zip" >&2; exit 1; }
echo "    OK (${SIZE}, zip verified)"

if [ -n "${BACKUP_BUCKET}" ]; then
  echo ">>> 4/4 Upload to s3://${BACKUP_BUCKET}/packages/"
  aws s3 cp "${OUT_FILE}" "s3://${BACKUP_BUCKET}/packages/$(basename "${OUT_FILE}")" --no-progress
  echo "    OK"
else
  echo ">>> 4/4 BACKUP_BUCKET not set — kept locally at ${OUT_FILE}"
fi
