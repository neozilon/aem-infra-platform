# Runbook — spinning the platform up for a new client / fresh account

End-to-end procedure to stand the whole platform up from scratch in a new
GitHub owner + new AWS account. Times assume nothing exists yet.
**Total: ~2 hours, of which ~35 min is AEM booting.**

## 0. Prerequisites (the client must provide)

| Item | Notes |
|---|---|
| AEM 6.5 license + binaries | quickstart jar, `license.properties`, dispatcher module (x86_64 ssl3.0). **The client must own an Adobe license** — binaries are never in git |
| GitHub account/org + PAT | classic token, `repo` + `workflow` scopes |
| AWS account on the **Paid plan** | Free-plan accounts cannot launch AEM-sized instances (hard blocker) |
| AWS vCPU quota ≥ 16 | Service Quotas → EC2 → "Running On-Demand Standard instances" (new accounts start at 5; increase is usually auto-approved) |
| An admin IAM access key | used ONCE for the global bootstrap, then deleted |
| Workstation | terraform ≥ 1.5, aws CLI, git. (JDK 21 + Docker only for the local-parity stack) |

## 1. Repository bootstrap (~5 min)

```bash
GITHUB_TOKEN=ghp_xxx ./bootstrap/bootstrap.sh -o <owner> [-n <repo>] -y
git remote add origin https://github.com/<owner>/<repo>.git
git fetch origin main
git merge -s ours --allow-unrelated-histories FETCH_HEAD -m "Merge auto-init"
git push origin main
```

Free GitHub plan → set `TF_VAR_repository_visibility=public` (branch
protection/environments need a paid plan on private repos).

## 2. AWS global plumbing (~10 min)

1. Edit the defaults in `terraform/global/main.tf` (`github_repository`,
   `budget_email`) or pass as TF_VARs.
2. Set the admin key as **temporary** repo secrets
   `AWS_BOOTSTRAP_ACCESS_KEY_ID` / `AWS_BOOTSTRAP_SECRET_ACCESS_KEY`
   (e.g. via `bootstrap/` with `TF_VAR_repository_secrets`).
3. Dispatch the **bootstrap-aws** workflow → creates OIDC provider, per-env
   roles, tfstate bucket + lock table, seed bucket, budget alarm.
4. **Delete the temporary secrets** (re-apply `bootstrap/` with
   `TF_VAR_repository_secrets='{}'`), and delete the IAM key when done.

## 3. Wire the account into the repo (~10 min)

1. **Backends:** in `terraform/envs/*/providers.tf` set the state bucket name
   (`aem-platform-tfstate-<ACCOUNT_ID>`) — 3 files, same value.
2. **Binaries:** `aws s3 cp` the jar, license and x86_64 dispatcher tarball to
   the seed bucket. Filenames must match `terraform/envs/*/variables.tf`
   defaults (or adjust the tfvars).
3. **Actions variables** (via `bootstrap/` TF_VARs or the GitHub UI):
   - repo: `BINARIES_SEED_BUCKET`
   - per env: `AWS_ROLE_ARN` = `arn:aws:iam::<ACCOUNT_ID>:role/gha-aem-<env>`
4. Commit + push the backend change.

## 4. Deploy dev (~45 min, mostly AEM boot)

1. Dispatch **deploy-infra** (dev / apply) — or just push; merges to main
   touching `terraform/**` auto-deploy dev.
2. From the run output take `binaries_bucket` and `package_backup_bucket`
   (random suffixes!) and set them as dev environment variables
   `BINARIES_BUCKET` / `BACKUP_BUCKET`.
3. Wait for AEM readiness (~15–20 min after apply; check via SSM or wait for
   the ALB to answer). ⚠️ Do NOT set `AEM_ADMIN_PASSWORD` yet — instances
   boot with admin/admin and the workflows use the secret as the current
   credential.
4. Dispatch **deploy-app** (dev) → installs the site on Author + all Publish.
5. Dispatch **configure** (dev, harden=false) → replication + flush per pair.
6. Verify: `http://<alb_dns_name>/content/aemdemo/us/en.html` → 200.

## 5. Harden + backups (~10 min)

1. Set the dev environment secret `AEM_ADMIN_PASSWORD` (strong value; store it
   in the client's vault).
2. Dispatch **configure** (dev, harden=true) → rotates admin, re-points
   replication, smoke-checks.
3. Dispatch **backup** (dev) → verify the package lands in the backup bucket.
   (EBS snapshots: the DLM policy runs on its own schedule.)

## 6. Optional demos

- **Elasticity:** set `publish_pair_count = 2` in `dev.tfvars`, push, wait for
  the new pair (~25 min), re-dispatch **deploy-app** + **configure**; then back
  to 1 and push. If hardened, harden=true on configure so the new publish gets
  rotated.
- **Stage/prod:** dispatch deploy-infra for the environment — the run pauses
  until the required reviewer approves (that's the O4 gate working).

## 7. Tear down (~10 min)

Dispatch **deploy-infra** (env / destroy). Buckets are `force_destroy` (except
the prod backup bucket, by design). Then verify nothing billable remains:
instances, NAT, ALBs, EIPs, non-default VPCs, stray volumes.

## Known limitations (honest list for a client conversation)

- **HTTP only** out of the box — HTTPS needs an ACM cert + domain
  (`certificate_arn` variable is already wired).
- **Author has no ALB route by default** (`author_host` empty): authors reach
  it via SSM port-forward. Set `author_host` + DNS for browser access.
- The `BINARIES_BUCKET`/`BACKUP_BUCKET` variables must be set manually after
  the first apply (bucket names carry random suffixes).
- The admin-password secret has an ordering constraint (see steps 4–5).
- Scaling is explicit (variable through the pipeline), not autoscaling.
- Single region; DR/observability/CDN are documented future work.
