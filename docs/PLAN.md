# Master Project Plan

**Project:** Automated platform for provisioning infrastructure and initial deployment of AEM projects using Terraform and GitHub Actions
**Author:** Fede Arriola
**Date:** 2026-07-05 · **Status:** DRAFT — pending scope lock

---

## 1. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Primary cloud | **AWS** | Most mature Terraform provider; most AEM reference architectures; academically defensible. Design stays extensible to Azure/GCP (thesis material). |
| AEM version | **AEM 6.5** (licensed quickstart jar + license file) | Real binaries available; on-prem model maps cleanly to IaaS provisioning (AEMaaCS would remove the infrastructure problem entirely). |
| Deployment strategy | **Local-first, then real AWS** | Validate the full topology with Docker at zero cost; apply identical Terraform to AWS for the final demo. Optional second provider as stretch goal. |
| Deliverable language | **Spanish** (report + slides); English for code/repo | Matches university requirement and industry convention. |
| Exam framing | Production-oriented modular prototype on one cloud, extensible design | Ambitious but defendable scope. |

## 2. Objectives (measurable)

1. **O1 — Repo bootstrap:** given only a GitHub token, the platform creates the project repository, branch protection, environments (dev/stage/prod), and Actions secrets. *Metric: one command, < 2 min.*
2. **O2 — Environment provisioning:** `terraform apply` creates a complete environment (network + Author + Publish + Dispatcher) from parameterized modules. *Metric: DEV, STAGE, PROD provisioned from the same modules, differing only in tfvars.*
3. **O3 — 1:1 elasticity:** changing one variable (`publish_pair_count`) scales Publish and Dispatcher together. *Metric: scale 1→2→1 demonstrated.*
4. **O4 — CI/CD:** GitHub Actions validates, plans, and applies infrastructure and deploys the AEM application per environment with approval gates. *Metric: merge-to-main → DEV auto-deploy; STAGE/PROD gated.*
5. **O5 — Operational baseline:** replication agents configured automatically; backup strategy implemented; security baseline applied. *Metric: publish→dispatcher flush works; snapshot policy visible; admin password rotated.*
6. **O6 — Demo site:** an AEM Maven-archetype site deployed end-to-end and reachable through the Dispatcher. *Metric: public URL serves cached pages.*
7. **O7 — Documentation:** Spanish written report + presentation + diagrams covering design, implementation, and results.

## 3. Architecture overview

### 3.1 Per-environment topology (DEV = STAGE = PROD, parameterized)

```
                        ┌────────────────────────── VPC (per env) ──────────────────────────┐
                        │                                                                    │
 Internet ──► ALB ──►   │  public subnets: ALB, NAT GW                                       │
 (HTTPS)                │  private subnets:                                                  │
                        │   ┌──────────┐      ┌─────────────────── pair group ────────────┐ │
   Authors ──► Author   │   │  AUTHOR  │      │  ┌────────────┐ 1:1  ┌──────────────────┐ │ │
   (via ALB   │  EC2    │   │  :4502   │─repl─┼─►│ PUBLISH n  │◄─────│ DISPATCHER n     │ │ │
   host rule) └─────────┘   └──────────┘      │  │ :4503      │flush │ Apache+module :80│◄┼─┼── ALB target
                        │                     │  └────────────┘      └──────────────────┘ │ │
                        │                     │        × publish_pair_count               │ │
                        │                     └───────────────────────────────────────────┘ │
                        │  SSM Session Manager (no SSH bastion) · S3 artifacts · DLM backups │
                        └────────────────────────────────────────────────────────────────────┘
```

Key design points:

- **One architectural model, three parameter sets.** `envs/dev`, `envs/stage`, `envs/prod` are thin roots calling shared modules with different tfvars (instance sizes, pair count, backup retention, deletion protection).
- **1:1 Publish:Dispatcher scaling** implemented as a `publish-pair` Terraform module instantiated with `count = var.publish_pair_count`. Each pair = 1 Publish EC2 + 1 Dispatcher EC2 wired together (dispatcher renders only its paired publish; flush agent points back at its dispatcher). Controlled scaling by variable change through the pipeline — auditable and reproducible. ASG-based autoscaling documented as future work.
- **Dispatcher** = Apache httpd + Adobe Dispatcher module, with filter rules, cache config, and cache invalidation (flush) enabled.
- **Access:** no public SSH; AWS SSM Session Manager. Author reachable through ALB host-based routing (dev/stage restricted by IP allowlist var).
- **AEM binaries** (quickstart jar, license, dispatcher module) live in a private S3 bucket; instances pull them at bootstrap via instance-profile IAM role. Binaries are NEVER committed to git.

### 3.2 Provisioning & delivery flow

```
 bootstrap.sh (GitHub token)
   └─► Terraform github provider: create repo, branches, environments, secrets
        └─► git push platform code
             └─► GitHub Actions
                  ├─ ci.yml           lint + terraform fmt/validate + tflint + checkov
                  ├─ deploy-infra.yml  plan (PR) / apply (merge) per env, OIDC to AWS
                  ├─ deploy-app.yml    mvn build → deploy content packages to Author/Publish
                  └─ configure.yml     replication agents + dispatcher flush + admin rotation
```

### 3.3 Local-first parity

`docker/docker-compose.yml` runs the same logical topology on the laptop: `author` (4502), `publish` (4503), `dispatcher` (httpd + dispatcher module, 8080). Same bootstrap scripts, same dispatcher config, same demo site deployment — proving the model before any cloud spend.

## 4. Repository structure (monorepo)

```
aem-infra-platform/
├── bootstrap/              # O1: repo creation from a token
│   ├── main.tf             # terraform github provider: repo, branch protection,
│   │                       # environments dev/stage/prod, actions secrets/vars
│   └── bootstrap.sh        # one-command wrapper
├── terraform/
│   ├── modules/
│   │   ├── network/        # VPC, subnets, NAT, SGs, VPC endpoints
│   │   ├── author/         # Author EC2, EBS, IAM, bootstrap user-data
│   │   ├── publish-pair/   # 1 Publish + 1 Dispatcher, wired 1:1
│   │   ├── alb/            # ALB, listeners, host rules, target groups
│   │   ├── backup/         # DLM snapshot policies + S3 package backup
│   │   └── binaries/       # S3 bucket + upload of AEM jar/license/dispatcher module
│   └── envs/
│       ├── dev/            # main.tf + dev.tfvars   (small sizes, 1 pair)
│       ├── stage/          # stage.tfvars           (prod-like, 1–2 pairs)
│       └── prod/           # prod.tfvars            (2 pairs, deletion protection,
│                           #  longer backup retention, stricter SGs)
├── docker/                 # local parity: author, publish, dispatcher images + compose
├── scripts/
│   ├── install-aem.sh      # unpack jar, set runmode, JVM opts, systemd unit
│   ├── configure-replication.sh   # author→publish agents, publish→dispatcher flush
│   ├── harden.sh           # rotate admin pwd, disable default users, prod runmode checks
│   └── backup-packages.sh  # content package export to S3
├── demo-site/              # AEM Maven archetype project (the deployable demo)
├── .github/workflows/      # ci.yml, deploy-infra.yml, deploy-app.yml, configure.yml
└── docs/                   # this plan, diagrams, ADRs, runbooks; report sources (Spanish)
```

## 5. Work plan — phases

| # | Phase | Deliverable | Effort |
|---|---|---|---|
| 0 | **Planning & skeleton** (this doc) | PLAN.md, diagrams, repo scaffold | done in session 1 |
| 1 | **Local AEM stack** | Docker author/publish/dispatcher running; install scripts | 2–3 sessions |
| 2 | **Demo site** | Maven archetype project builds and deploys locally | 1–2 sessions |
| 3 | **Repo bootstrap automation** | `bootstrap.sh` + GitHub provider TF; repo created from token | 1 session |
| 4 | **Terraform modules** | network, binaries, author, publish-pair, alb, backup — validated (`fmt`/`validate`/tflint/checkov) | 3–4 sessions |
| 5 | **Environments** | dev/stage/prod roots + tfvars; remote state (S3+lock) | 1–2 sessions |
| 6 | **CI/CD pipelines** | 4 workflows, OIDC auth, env protection gates | 2 sessions |
| 7 | **Ops baseline** | replication config, hardening, backup policies | 2 sessions |
| 8 | **Cloud validation** | Real AWS deploy of DEV (then STAGE/PROD briefly), demo site through Dispatcher, scaling demo 1→2→1, evidence capture (screenshots/recordings), then destroy | 2–3 sessions |
| 9 | **Written report (Spanish)** | Full document: antecedentes, problema, justificación, objetivos, marco teórico, arquitectura, implementación, pruebas, conclusiones | 3–4 sessions |
| 10 | **Presentation** | Spanish .pptx for the board | 1 session |

Phases 1–2 can run in parallel with 3–4. Report sections get drafted as each phase completes (not left to the end).

## 6. Cost estimate (AWS, only while running)

| Item | DEV (validation) | Full 3-env demo |
|---|---|---|
| Author (t3.xlarge, 16 GB) | ~$0.17/h | ×3 |
| Publish+Dispatcher pair (t3.large + t3.small) | ~$0.11/h | ×4 pairs total |
| ALB + NAT + EBS + S3 | ~$0.10/h | ~$0.30/h |
| **Total** | **≈ $0.40/h ≈ $9/day** | **≈ $1.30/h ≈ $30/day** |

Strategy: develop against Docker (free); bring DEV up for integration testing hours-at-a-time; bring all three envs up only for final evidence capture (1–2 days), then `terraform destroy`. Realistic total cloud spend: **$50–150**.

## 7. Security baseline (in scope)

Private subnets for all AEM nodes; SSM instead of SSH; IAM least-privilege instance profiles; GitHub→AWS via OIDC (no long-lived keys); secrets in GitHub Environments + SSM Parameter Store; admin password rotation on first boot; default users disabled; Dispatcher filter deny-by-default; prod runmodes; encrypted EBS/S3; IP allowlist for Author in non-prod.

## 7b. Version & upgrade strategy (service packs)

All component versions are **pinned variables**, upgrades are config changes through the pipeline — never manual patching:

| Component | Delivery | Pin | Upgrade path |
|---|---|---|---|
| AEM 6.5 LTS base | `cq-quickstart-6.6.0.jar` (S3) | `aem_version = "6.6.0"` | New jar for LTS baseline changes |
| Service pack (6.6.x LTS line) | content package (S3) | `aem_service_pack` | Installed by `install-aem.sh` after base boot; upgrade = bump var → rolling replace of Publish pairs (immutable), in-place package install on Author (stateful) → validated in DEV → promoted via the normal pipeline. ⚠️ Classic 6.5.x SPs (e.g., 6.5.25.0) are NOT installable on LTS. |
| Dispatcher module | `dispatcher-apache2.4-linux-x86_64` tar.gz (S3) | `dispatcher_version` | Bump var → replace Dispatcher instances. Needs a modern build (4.3.7+); ssl1.0 builds don't link against OpenSSL 3 on AL2023. |
| Java | 21 (Temurin/Corretto for dev; Oracle JDK officially supported by Adobe) | `java_version = "21"` | Follows Adobe's LTS support matrix |

Target platform: **Apache httpd 2.4 on x86_64 Linux (Amazon Linux 2023, t3 = x86_64)**. Locally, the dispatcher container runs `platform: linux/amd64` since Adobe publishes no aarch64 build (relevant on Apple Silicon).

An upgrade runbook (`docs/runbooks/upgrade-service-pack.md`) is part of the maintenance-guidance deliverable, and the SP bump will be demonstrated as evidence for the report.

## 8. Backup strategy (in scope)

Tier 1 — **EBS snapshots** via AWS Data Lifecycle Manager (daily; retention: dev 3d / stage 7d / prod 30d). Tier 2 — **content package export** to versioned S3 (scheduled script). Restore procedure documented as a runbook and tested once for the report.

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| AEM 6.5 licensing — binaries must stay private | Legal/academic | S3 private bucket + .gitignore; never in repo; note in report |
| AEM memory hunger on small instances | Demo instability | t3.xlarge for Author; JVM tuning; document sizing |
| Cloud cost creep | Budget | Local-first; destroy discipline; budget alarm in TF |
| AEM startup time (~10 min) breaks pipeline timing | Flaky CI | Health-check wait loops in scripts; async configure step |
| Scope creep (multi-cloud, DR, observability) | Missed deadline | Explicit out-of-scope list; future-work chapter |
| Old AEM 6.5 vs current docs (AEMaaCS era) | Confusion | Pin to 6.5 docs; justify choice in report |

## 10. Out of scope (exam) → future work (thesis)

Multi-cloud implementation (Azure/GCP), multi-region DR, autoscaling via ASG+alarms, full observability stack, CDN/WAF, compliance hardening, real content migration. Each gets a paragraph in the "Trabajo futuro" chapter.

## 11. Deliverables mapping

| University requirement | Produced by |
|---|---|
| Written report (Spanish) | `docs/report/` drafted per phase → final .docx |
| Working project | This repo, deployed on AWS (evidence captured) |
| Presentation | `.pptx` from report content |
| Diagrams / artifacts | `docs/diagrams/` (Mermaid + exported images), workflow runs, screenshots |

## 12. Immediate next steps

1. Lock this plan (review with Fede).
2. Fede provides: AEM 6.5 quickstart jar + license file + dispatcher module → placed in a local `binaries/` folder (gitignored).
3. Fede provides: GitHub personal access token (repo scope) and AWS account for later phases.
4. Start Phase 1 (local Docker stack) — needs the binaries.
5. Phase 3 (bootstrap) can start with just the token, independent of binaries.
