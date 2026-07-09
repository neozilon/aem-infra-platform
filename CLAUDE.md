# AEM Infrastructure Automation Platform — project context

University final project (Fede Arriola). Automated provisioning + initial deployment of AEM projects with Terraform and GitHub Actions. **Read `docs/PLAN.md` first** — it is the master plan (architecture, phases, scope). Follow it.

## Locked decisions (never re-ask)

- Cloud: **AWS** (extensible to Azure/GCP as future work)
- AEM: **6.5 LTS** (`binaries/cq-quickstart-6.6.0.jar`, Java 21). License from 2020, accepted on local boot.
- Dispatcher: **4.3.8**, ssl3.0 builds (x86_64 for AWS, aarch64 for local Apple Silicon)
- Strategy: local Docker first → real AWS after validation
- Written report + presentation: **Spanish**. Code/repo/docs: English.
- 1:1 Publish:Dispatcher scaling via `publish-pair` Terraform module, count-driven

## Current status (2026-07-06)

- Phases 0–1 DONE: plan, diagrams, skeleton, local Docker stack (author :4502, publish :4503, dispatcher :8080) all running healthy
- Phase 2 DONE: `demo-site/aemdemo` (archetype 56) builds and deploys end-to-end. Verified:
  - `mvn clean install -PautoInstallSinglePackage` → author, `-PautoInstallSinglePackagePublish` → publish (both green)
  - `./scripts/configure-replication.sh` → author→publish agent test SUCCEEDED, dispatcher flush agent created
  - http://localhost:8080/content/aemdemo/us/en.html + all clientlibs render 200 through the dispatcher
  - Dispatcher filter fix: clientlibs were `blocked` under `/path "/etc.clientlibs/*"`; switched to `/url` (see gotcha) and rebuilt the image
- Phase 3 DONE (executed 2026-07-08): `bootstrap/` created **github.com/neozilon/aem-infra-platform** (public) with branch protection (1 approval), dev/stage/prod environments (stage+prod gated with `neozilon` reviewer), Actions variables (AEM_VERSION/DISPATCHER_VERSION/JAVA_VERSION/AWS_REGION). Local git initialised; code pushed to `origin/main`. `terraform plan` idempotent (no changes). Re-run: `GITHUB_TOKEN=ghp_xxx ./bootstrap/bootstrap.sh -o neozilon` (visibility=public, reviewers set via TF_VARs — see gotcha)
- Phase 4 DONE (modules validated, NOT applied — AWS apply is Phase 8): `terraform/modules/{network,binaries,author,publish-pair,alb,backup}`. All pass `terraform fmt -recursive` + per-module `validate` (Terraform 1.15, aws ~> 5.60). Key designs: 1:1 elasticity via `publish-pair count`; ALB target-group ATTACHMENTS live in the env root (not the alb module) to avoid a module cycle; dispatcher bootstrap reuses the Phase-2 `/url` farm config templated with the paired publish IP; SSM/IMDSv2/encryption/least-priv baseline
- Phase 5 DONE (validated, NOT applied): shared composition module `terraform/modules/aem-environment` wires all 6 modules + ALB TG attachments; thin roots `terraform/envs/{dev,stage,prod}` have IDENTICAL `.tf` and differ ONLY by `<env>.tfvars` (dev 1 pair/retain 3, stage 1 pair/retain 7, prod 2 pairs/per-AZ NAT/retain 30). All 3 roots pass `validate`. **State is LOCAL for now**; S3+DynamoDB backend is written commented in each `envs/*/providers.tf` — uncomment in Phase 8. Binaries paths default to `../../../binaries/*` (x86_64 dispatcher build). No `apply`/`plan` yet (needs AWS creds)
- Phase 6 DONE: 4 workflows in `.github/workflows/` — `ci.yml` (fmt/validate all roots + tflint + checkov soft-fail + mvn package; job contexts `ci-terraform`/`ci-app` are now REQUIRED checks on main via bootstrap), `deploy-infra.yml` (push→dev auto plan+apply; stage/prod+destroy via dispatch behind env gates; OIDC via env var AWS_ROLE_ARN; binaries pulled from seed bucket var BINARIES_SEED_BUCKET), `deploy-app.yml` (build→S3→SSM install on author+publish via vars.BINARIES_BUCKET), `configure.yml` (per-pair replication+flush agents via SSM on author, fetching scripts/configure-replication.sh from the repo raw URL). All AWS jobs no-op with a ::notice until Phase 8 sets AWS_ROLE_ARN etc. Also: publish-pair SGs restructured to standalone rules (publish↔dispatcher cross-reference = cycle) + NEW dispatcher←publish :80 flush rule; configure-replication.sh parameterized with AGENT_NAME (pair N agents), regression-tested on the local stack
- NEXT: Phase 7 (ops scripts: install-aem.sh, harden.sh, backup-packages.sh). Phase 8 = real AWS (needs Fede's AWS account): seed bucket + OIDC role + state bucket, uncomment backends, set env vars/secrets, run pipelines

## Environment gotchas (hard-won, respect these)

- **JAVA_HOME must be JDK 21** for Maven: `export JAVA_HOME=$(/usr/libexec/java_home -v 21)`. JDK 24 breaks the archetype plugin (Groovy can't parse class file v68). Project compiles to release 11 — fine on 21.
- Archetype generation needs plugin **3.3.1** (3.2.1's Groovy 2.4 lacks groovy.xml.XmlSlurper)
- Docker credential helper: PATH may need `/Applications/Docker.app/Contents/Resources/bin`
- `binaries/` is **gitignored, licensed Adobe software — NEVER commit or upload except to the private S3 bucket** (terraform module `binaries`)
- AEM containers take 10–15 min on first boot; readiness = `curl -sf localhost:4502/libs/granite/core/content/login.html` → 200
- The classic service pack `aem-service-pkg-6.5.25.0.zip` in binaries/ is NOT installable on LTS — only 6.6.x LTS packs apply
- Dispatcher farm `docker/dispatcher/conf/publish-farm.any` uses env vars (`PUBLISH_HOST`, `PUBLISH_PORT`, `FLUSH_ALLOWED_IP`) — same file serves local and AWS
- Dispatcher filter allow-rules must use `/url` not `/path` for clientlibs: with `DispatcherUseProcessedURL On`, `/path "/etc.clientlibs/*"` is decomposed on the dot in `etc.clientlibs` and never matches → requests `blocked` (404). `/url` matches the raw URI (Dispatcher SDK convention). Diagnose via `docker exec aem-dispatcher tail logs/dispatcher.log` (look for `blocked`)
- admin/admin is local-only; hardening happens in Phase 7 (`scripts/harden.sh`, to be written)
- Terraform install: core `brew install terraform` is gone (HashiCorp BSL). Use `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` (installed: 1.15.7). GitHub provider = `integrations/github ~> 6.2`
- GitHub free plan does NOT allow branch protection / environments on **private** repos — bootstrap defaults to private; set `repository_visibility = "public"` on free (no licensed binaries are ever committed, so public is safe)
- Terraform `for_each` cannot iterate a `sensitive` variable directly — wrap the keys in `nonsensitive()` and pull each value from the variable inside the resource (see `bootstrap/main.tf` secret resources)
- GitHub provider branch-protection resources (`github_branch_protection` AND `_v3`) issue GraphQL actor-`id` queries needing `read:org` scope — they FAIL with a plain `repo+workflow` token. bootstrap sets branch protection via a `null_resource` REST PUT instead (works with repo scope). Empty-valued Actions variables are rejected by GitHub (skip them). If a failed apply leaves `github_branch_protection.default` in state, `terraform state rm` it or every later refresh errors on read:org
- Pushing to the bootstrapped repo: branch protection blocks force-push even for admins; local git init has history unrelated to GitHub's auto-init README. Reconcile with `git merge -s ours --allow-unrelated-histories FETCH_HEAD` then a normal push (admin bypasses the PR rule with enforce_admins=false)

## Commands

- Local stack: `docker compose -f docker/docker-compose.yml up -d --build` (from repo root; Docker Desktop needs ≥12 GB RAM)
- Clean restart: `docker compose -f docker/docker-compose.yml down -v` (wipes AEM repos)
- Logs: `docker logs -f aem-author` / `aem-publish` / `aem-dispatcher`

## Conventions

- Terraform: modules in `terraform/modules/`, env roots in `terraform/envs/{dev,stage,prod}` — envs differ ONLY by tfvars
- All versions pinned as variables (`aem_version`, `aem_service_pack`, `dispatcher_version`, `java_version`) — upgrades are var bumps through the pipeline, see PLAN.md §7b
- Evidence for the report (screenshots, outputs) goes in `docs/report/evidence/`
- Draft report sections in Spanish in `docs/report/` as phases complete — don't leave writing to the end
