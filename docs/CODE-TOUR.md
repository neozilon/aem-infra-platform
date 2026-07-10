# Code tour — how everything is plumbed together

A guided reading order for understanding the platform. Read top to bottom:
each stop builds on the previous one. Times are honest estimates for a careful
read. The hard-won environment lessons live in `CLAUDE.md` ("gotchas") — keep
it open in a second tab.

## Stop 1 — The local stack: the topology in miniature (~30 min)

Start here because everything else replicates this shape in the cloud.

1. **`docker/docker-compose.yml`** — three services: `author` (:4502),
   `publish` (:4503), `dispatcher` (:8080). Note the env vars: runmodes, JVM
   opts, and `PUBLISH_HOST`/`FLUSH_ALLOWED_IP` feeding the dispatcher.
2. **`docker/aem/Dockerfile` + `entrypoint.sh`** — how AEM actually starts:
   the quickstart jar, `-r author,dev` runmodes, `-nofork` foreground. This
   exact pattern later becomes the AWS systemd unit (after `bin/start` burned
   us — see gotchas).
3. **`docker/dispatcher/conf/publish-farm.any`** — the security core:
   deny-by-default `/filter`, the **`/url` (not `/path`) clientlib rule**
   (Phase 2's big lesson), `/cache` with `allowedClients` restricting flush to
   the paired publish. The AWS dispatcher renders this same config.
4. **`scripts/configure-replication.sh`** — the author→publish agent and the
   publish→dispatcher flush agent, created via curl against AEM's Sling
   endpoints. `AGENT_NAME` parameterizes it for pair N.

**Mental model to take away:** Author *pushes* content to each Publish
(replication agent); each Publish *pushes* invalidations to its Dispatcher
(flush agent); the Dispatcher only *pulls* renders from its one Publish. 1:1:1.

## Stop 2 — Governance as code: bootstrap/ (~20 min)

5. **`bootstrap/main.tf`** — the GitHub provider creates the repo, the
   environments (stage/prod with required reviewers), Actions variables.
   Two things to notice: branch protection is a **REST `null_resource`**
   (the provider's own resources demand `read:org` scope — gotcha), and the
   sensitive-map `for_each` dance with `nonsensitive()`.
6. **`bootstrap/bootstrap.sh`** — the O1 "one command". Token via env, never
   on disk.

## Stop 3 — The Terraform layer, bottom-up (~90 min, the core)

Read the modules in dependency order; for each, `variables.tf` first (the
interface), then `main.tf` (the implementation):

7. **`terraform/modules/network/`** — VPC, public/private subnets, NAT,
   **S3 gateway endpoint** (binaries pulls bypass NAT) and **SSM interface
   endpoints** (Session Manager without bastion). Everything AEM sits in
   private subnets.
8. **`terraform/modules/binaries/`** — the private, versioned, TLS-only S3
   bucket + uploads of the licensed artifacts. `force_destroy` because its
   content is reproducible from the seed bucket.
9. **`terraform/modules/author/`** — EC2 + dedicated EBS data volume + IAM
   (SSM core + read-binaries + optional write-backups) + SG. The instance
   bootstraps via **`terraform/modules/templates/aem-node-user-data.sh.tftpl`**,
   which *embeds* `scripts/install-aem.sh` verbatim — single source of install
   logic. Note the **device-wait loop** (EBS attach race) in the template.
10. **`terraform/modules/publish-pair/`** — THE design centerpiece. One
    Publish + one Dispatcher wired 1:1. Study the security groups: they
    reference each other (render one way, flush the other), so rules are
    **standalone resources** to break the cycle. The dispatcher user-data
    templates the farm config with the paired publish's IP.
11. **`terraform/modules/alb/`** — listeners, dispatcher target group,
    optional host-routed author TG. Attachments are NOT here (cycle avoidance
    — see next stop).
12. **`terraform/modules/backup/`** — Tier 1 (DLM snapshot policy selecting
    volumes by the `Backup` tag) + Tier 2 bucket.
13. **`terraform/modules/aem-environment/`** — the composition module: wires
    all six, `publish_pair` with `count = publish_pair_count` (the O3
    elasticity knob), and hosts the ALB target-group **attachments** so the
    ALB↔instances dependency cycle never forms.
14. **`terraform/envs/dev/`** — a thin root: `main.tf` just calls the
    composition module; **`dev.tfvars` is the ONLY thing that differs between
    environments**. Compare `dev.tfvars` vs `prod.tfvars` (pairs, NAT,
    retention). Note `backend "s3" {}` is EMPTY — the pipeline injects the
    account-derived config.
15. **`terraform/global/`** — the once-per-account root: GitHub OIDC provider,
    the three `gha-aem-*` roles (trust condition = `repo:…:environment:<env>`
    — this line is why GitHub approvals gate AWS), state bucket + lock table,
    seed bucket, budget.

## Stop 4 — The delivery plane: workflows in execution order (~60 min)

16. **`.github/workflows/ci.yml`** — fmt/validate/tflint/checkov + Maven
    build. Its job names are the required status checks on `main`.
17. **`.github/workflows/bootstrap-aws.yml`** — one-shot: applies
    `terraform/global` with a temporary human key (only workflow that ever
    sees a long-lived credential).
18. **`.github/workflows/deploy-infra.yml`** — the heart: OIDC auth, binaries
    sync from the seed bucket, **`-backend-config` derived from the account
    ID**, plan/apply/destroy. Push-to-main auto-applies dev; stage/prod wait
    for your approval (the `environment:` line).
19. **`.github/workflows/deploy-app.yml`** — build → S3 → **SSM install** on
    every author/publish (instances are private; SSM is the only door). Note
    the bucket **discovery by tags** and the **password auto-detection**
    (currentuser.json identity check).
20. **`.github/workflows/configure.yml`** — per-pair loop: harden first
    (optional), then replication+flush per pair via SSM, reusing the Stop-1
    scripts fetched from the repo at the exact running commit.
21. **`.github/workflows/backup.yml`** — cron + dispatch Tier-2 export.
22. **`.github/workflows/provision.yml`** — the one-click orchestrator:
    chains 18→(AEM readiness wait)→19→20→smoke test via `workflow_call`,
    prints the site URL in the run summary.

## Stop 5 — Ops scripts (~30 min)

23. **`scripts/install-aem.sh`** — unpack, systemd unit (**foreground
    `java -nofork`**, the Stop-1 pattern), readiness wait.
24. **`scripts/harden.sh`** — read the header comments first: they encode the
    two nastiest AEM 6.5 discoveries (fake-success password endpoints; publish
    falling back to `anonymous` with HTTP 200). Then `whoami_aem()` and the
    rotation flow.
25. **`scripts/backup-packages.sh`** — packmgr create→filter→build→download→S3.

## Stop 6 — The portal (~30 min)

26. **`portal/server.js`** — every endpoint maps to a runbook step. Note:
    GitHub via REST, AWS via **aws CLI shell-out** (the JS/Go SDKs can't reach
    AWS from this Mac — gotcha), secrets sealed with libsodium for the GitHub
    API, credentials memory-only.
27. **`portal/public/app.js`** — the deploy button = dispatch `provision.yml`
    + poll `/runs/:id/jobs` into the timeline.

## Cross-cutting threads to trace once you know the pieces

- **A content activation**, end to end: author UI → replication agent →
  publish `/bin/receive` → flush agent → dispatcher `invalidate.cache` →
  next request re-caches. (Stops 1, 3.10, 4.20)
- **A scale-up**: tfvars change → push → deploy-infra → new pair boots (user
  data → install-aem) → ALB TG attachment → configure adds agent `publishN`.
  (Stops 3.13, 4.18, 4.20)
- **An identity**: workflow job → GitHub OIDC token → `gha-aem-dev` trust
  condition → STS temp creds → terraform/aws. No stored keys anywhere.
  (Stops 3.15, 4.18)

## Reading companions

- `docs/PLAN.md` — why each piece exists (the contract everything follows)
- `CLAUDE.md` — the gotcha list: every scar, in one place
- `docs/report/` (Spanish) — the narrative version with evidence
- `docs/runbooks/new-client-setup.md` — the operational view
