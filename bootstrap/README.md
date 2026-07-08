# bootstrap — repository creation from a GitHub token (O1)

Terraform (GitHub provider) that provisions the platform repository and its
governance in one command:

- the repository (`aem-infra-platform`), with squash/rebase merges and
  delete-branch-on-merge
- branch protection on `main` (required PR review, optional required status
  checks)
- deployment **environments** `dev`, `stage`, `prod` — `stage`/`prod` gated with
  required reviewers + protected-branch-only deploys (objective O4)
- Actions **variables** seeded with the pinned versions (`AEM_VERSION`,
  `DISPATCHER_VERSION`, `JAVA_VERSION`, …) and optional per-environment
  variables/secrets (e.g. AWS OIDC role ARNs, added in later phases)
- Dependabot vulnerability alerts

## Prerequisites

- Terraform ≥ 1.5 (`brew install hashicorp/tap/terraform`)
- A GitHub token with `repo` + `workflow` scope (classic PAT), or a
  fine-grained token with Administration/Actions/Environments write on the
  target owner.

## Usage

```bash
export GITHUB_TOKEN=ghp_xxx
./bootstrap.sh -o <github-owner> [-n <repo-name>] [-y]
```

`-o` is the user login or organization that will own the repo, `-n` overrides
the repo name, `-y` auto-approves. The token is read from `GITHUB_TOKEN` (or
prompted, never echoed) and passed to Terraform as `TF_VAR_github_token` — it is
never written to disk.

Manual Terraform is equivalent:

```bash
cp terraform.tfvars.example terraform.tfvars   # edit owner, etc.
export TF_VAR_github_token=ghp_xxx
terraform init && terraform apply
```

On success it prints the clone URL — push the platform code to it.

## Configuration

All inputs are in [variables.tf](variables.tf); see
[terraform.tfvars.example](terraform.tfvars.example) for the common ones.
Notable:

- `repository_visibility` — `private` (default) or `public`.
- `environment_reviewers` — usernames allowed to approve `stage`/`prod`
  deployments. Empty = environments created now, reviewers added later.
- `required_status_checks` — left empty until `ci.yml` exists (Phase 6), then
  set to the CI job contexts so PRs must pass CI to merge.
- `environment_variables` / `environment_secrets` — per-environment Actions
  config; AWS OIDC role ARNs go here once the AWS account exists.

## Notes

- **Paid-plan caveat:** GitHub requires a paid plan (Pro/Team/Enterprise) for
  branch protection and environments on **private** repositories. On the free
  plan use `repository_visibility = "public"` (no licensed binaries are ever
  committed, so the repo can be public) — or accept that those resources need
  the upgrade.
- State is local (`terraform.tfstate`, gitignored). This root is a one-shot
  bootstrap; the environment infrastructure (Phase 4+) uses its own remote
  state under `terraform/`.
- Re-running is idempotent; changing variables and re-applying updates the repo
  in place.
