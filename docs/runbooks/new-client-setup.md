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

## 3. Wire the account into the repo (~5 min)

1. **Binaries:** `aws s3 cp` the jar, license and x86_64 dispatcher tarball to
   the seed bucket. Filenames must match `terraform/envs/*/variables.tf`
   defaults (or adjust the tfvars).
2. **Actions variables** (via `bootstrap/` TF_VARs or the GitHub UI):
   - repo: `BINARIES_SEED_BUCKET`
   - per env: `AWS_ROLE_ARN` = `arn:aws:iam::<ACCOUNT_ID>:role/gha-aem-<env>`

That's all: the Terraform backend is derived from the account at runtime, and
the per-env buckets are discovered by tags — no file edits, no per-env bucket
variables.

## 4. Deploy (~45 min, mostly AEM boot) — ONE CLICK

Optionally set the environment secret `AEM_ADMIN_PASSWORD` first (the
workflows auto-detect whether instances are already rotated, so ordering no
longer matters). Then dispatch **provision** (environment, harden=true/false):

```
infra apply → wait for AEM readiness → deploy app → replication/flush
(+ hardening) → smoke test → the run summary prints the public site URL
```

For backups, dispatch **backup** once (it also runs daily by cron), and the
DLM snapshot policy operates on its own schedule.

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
- Scaling is explicit (variable through the pipeline), not autoscaling.
- Single region; DR/observability/CDN are documented future work.
