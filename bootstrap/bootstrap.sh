#!/usr/bin/env bash
# One-command repository bootstrap (objective O1).
# Given a GitHub token it creates the platform repo, branch protection,
# dev/stage/prod environments and Actions variables/secrets via Terraform.
#
#   GITHUB_TOKEN=ghp_xxx ./bootstrap.sh -o <owner> [-n <repo>] [-y]
#
# The token is read from GITHUB_TOKEN (or prompted, never echoed) and passed to
# Terraform as TF_VAR_github_token — it is never written to disk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

AUTO_APPROVE=""
OWNER="${TF_VAR_github_owner:-}"
REPO="${TF_VAR_repository_name:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") -o <github-owner> [-n <repo-name>] [-y]

  -o   GitHub owner (user login or org). Required (or set TF_VAR_github_owner).
  -n   Repository name (default: aem-infra-platform).
  -y   Auto-approve (skip the interactive apply confirmation).
  -h   Show this help.

Token: export GITHUB_TOKEN=ghp_... (or you will be prompted).
EOF
}

while getopts ":o:n:yh" opt; do
  case "$opt" in
    o) OWNER="$OPTARG" ;;
    n) REPO="$OPTARG" ;;
    y) AUTO_APPROVE="-auto-approve" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
  esac
done

command -v terraform >/dev/null 2>&1 || {
  echo "ERROR: terraform is not installed or not on PATH." >&2; exit 1; }

if [[ -z "$OWNER" ]]; then
  echo "ERROR: GitHub owner is required (-o <owner> or TF_VAR_github_owner)." >&2
  usage; exit 2
fi

# Token: env first, else prompt without echo.
TOKEN="${GITHUB_TOKEN:-${TF_VAR_github_token:-}}"
if [[ -z "$TOKEN" ]]; then
  read -r -s -p "GitHub token (input hidden): " TOKEN; echo
fi
[[ -n "$TOKEN" ]] || { echo "ERROR: no token provided." >&2; exit 2; }

export TF_VAR_github_token="$TOKEN"
export TF_VAR_github_owner="$OWNER"
[[ -n "$REPO" ]] && export TF_VAR_repository_name="$REPO"

echo ">>> terraform init"
terraform init -input=false

echo ">>> terraform apply (owner=${OWNER}${REPO:+, repo=${REPO}})"
if [[ -n "$AUTO_APPROVE" ]]; then
  terraform apply -input=false $AUTO_APPROVE
else
  terraform apply -input=false
fi

echo
echo ">>> Done. Repository details:"
terraform output
