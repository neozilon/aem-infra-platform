# AEM Infrastructure Automation Platform

Automated provisioning and initial deployment of **Adobe Experience Manager 6.5**
projects on AWS, driven end-to-end by **Terraform** and **GitHub Actions**.
From a GitHub token to a cached site behind the Dispatcher on a public URL —
no manual steps in between.

> University final project (Fede Arriola). Report and presentation in Spanish
> under `docs/report/`; code and docs in English. Master plan: [docs/PLAN.md](docs/PLAN.md).

## What it does

1. **Repo bootstrap (O1):** one command creates the GitHub repository, branch
   protection, dev/stage/prod environments (stage/prod approval-gated) and
   Actions variables — `bootstrap/`.
2. **Environment provisioning (O2):** parameterized Terraform modules build a
   full AEM topology per environment — VPC, Author, N× Publish+Dispatcher
   pairs, ALB, backups. Environments differ **only** in tfvars — `terraform/`.
3. **1:1 elasticity (O3):** `publish_pair_count = N` scales Publish and
   Dispatcher together through the pipeline (demonstrated 1→2→1 with zero
   downtime).
4. **CI/CD (O4):** five workflows (validate, infra, app, configure, backup)
   with GitHub→AWS **OIDC** (no long-lived keys) and environment gates.
5. **Ops baseline (O5):** replication + dispatcher flush per pair, admin
   password rotation, two-tier backups (EBS snapshots + content packages to S3).
6. **Demo site (O6):** AEM archetype site deployed to Author/Publish and served
   cached through the Dispatcher.

## Architecture (per environment)

```
 Internet ─► ALB ─► [ DISPATCHER n ◄─1:1─► PUBLISH n ] ×N ◄─repl─ AUTHOR
              (public)        (private subnets, SSM access, no SSH)
 Binaries: private S3 ─► instances pull at boot (IAM role)
 GitHub Actions ─OIDC─► per-env IAM role (trust = repo + environment)
```

Local parity: `docker/` runs the same topology (author :4502, publish :4503,
dispatcher :8080) with the same configs and scripts — everything is validated
locally first, at zero cloud cost.

## Repository map

| Path | Contents |
|---|---|
| `bootstrap/` | Terraform (GitHub provider) + `bootstrap.sh` — creates the repo/governance from a token |
| `terraform/global/` | Once per AWS account: OIDC provider, per-env roles, state bucket + lock, binaries seed bucket, budget alarm (applied by `bootstrap-aws.yml`) |
| `terraform/modules/` | `network`, `binaries`, `author`, `publish-pair`, `alb`, `backup` + the `aem-environment` composition module |
| `terraform/envs/{dev,stage,prod}` | Thin, identical roots; per-env `*.tfvars` |
| `.github/workflows/` | `ci`, `deploy-infra`, `deploy-app`, `configure`, `backup`, `bootstrap-aws` |
| `docker/` | Local parity stack (Author/Publish/Dispatcher images + compose) |
| `demo-site/` | AEM archetype project (the deployable) |
| `scripts/` | `install-aem.sh`, `configure-replication.sh`, `harden.sh`, `backup-packages.sh` |
| `docs/` | Master plan (`PLAN.md`), report chapters (Spanish), evidence, runbooks |
| `binaries/` *(gitignored)* | Licensed Adobe artifacts — **never committed**; distributed via private S3 |

## Quickstart

- **Local demo (free):** put the licensed binaries in `binaries/`, then
  `docker compose -f docker/docker-compose.yml up -d --build` and deploy the
  demo site (see `docs/report/fase2-sitio-demo.md`).
- **Full AWS spin-up for a new client/account:** follow
  [`docs/runbooks/new-client-setup.md`](docs/runbooks/new-client-setup.md)
  (~2 h end to end, ≈ $0.40/h while running, destroy when done).

## Status

All objectives validated on real AWS (2026-07-09) and the environment
destroyed afterward (cost discipline: create → validate → capture evidence →
destroy). See `docs/report/11-resultados.md` for measured times, costs and the
incident log.
