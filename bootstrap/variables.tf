variable "github_token" {
  description = "GitHub PAT with 'repo' + 'workflow' scope (classic) or equivalent fine-grained perms. Prefer passing via TF_VAR_github_token / GITHUB_TOKEN, never committed."
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub account (user login or organization) that will own the repository."
  type        = string
}

variable "repository_name" {
  description = "Name of the platform repository to create."
  type        = string
  default     = "aem-infra-platform"
}

variable "repository_description" {
  description = "Repository description."
  type        = string
  default     = "Automated provisioning and initial deployment of AEM projects with Terraform and GitHub Actions."
}

variable "repository_visibility" {
  description = "Repository visibility: private or public. Note: branch protection and environments on PRIVATE repos require a paid GitHub plan (Pro/Team/Enterprise)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.repository_visibility)
    error_message = "repository_visibility must be 'private' or 'public'."
  }
}

variable "repository_topics" {
  description = "Topics applied to the repository."
  type        = list(string)
  default     = ["aem", "terraform", "github-actions", "iac", "aws", "dispatcher"]
}

variable "default_branch" {
  description = "Default branch name (also the branch-protection pattern)."
  type        = string
  default     = "main"
}

# --- Governance -------------------------------------------------------------

variable "enforce_admins" {
  description = "Apply branch-protection rules to admins too. Keep false for a solo maintainer so direct pushes/bootstrap fixes remain possible."
  type        = bool
  default     = false
}

variable "required_pr_approvals" {
  description = "Number of approving reviews required to merge into the default branch."
  type        = number
  default     = 1
}

variable "required_status_checks" {
  description = "Status-check contexts required before merge — the ci.yml job names (Phase 6)."
  type        = list(string)
  default     = ["ci-terraform", "ci-app"]
}

# --- Environments -----------------------------------------------------------

variable "environments" {
  description = "GitHub deployment environments to create."
  type        = list(string)
  default     = ["dev", "stage", "prod"]
}

variable "protected_environments" {
  description = "Environments that require reviewer approval and may only deploy from protected branches (gated per objective O4)."
  type        = list(string)
  default     = ["stage", "prod"]
}

variable "environment_reviewers" {
  description = "GitHub usernames that can approve deployments to protected environments. Empty = environment created without required reviewers (add later)."
  type        = list(string)
  default     = []
}

variable "prod_wait_timer" {
  description = "Minutes to wait before a deployment to 'prod' can proceed (0 = none)."
  type        = number
  default     = 0
}

# --- Actions configuration --------------------------------------------------

variable "repository_variables" {
  description = "Repository-level Actions variables (non-secret). Keys must be UPPER_SNAKE_CASE. Seeds the pinned versions so pipelines read them centrally (see PLAN.md §7b)."
  type        = map(string)
  default = {
    AEM_VERSION        = "6.6.0"
    AEM_SERVICE_PACK   = ""
    DISPATCHER_VERSION = "4.3.8"
    JAVA_VERSION       = "21"
    AWS_REGION         = "us-east-1"
  }
}

variable "repository_secrets" {
  description = "Repository-level Actions secrets. Default empty — AWS OIDC uses role ARNs (non-secret vars), so most values live in environment_variables."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "environment_variables" {
  description = "Per-environment Actions variables, keyed by environment name then variable name. E.g. { dev = { AWS_ROLE_ARN = \"arn:...\" } }."
  type        = map(map(string))
  default     = {}
}

variable "environment_secrets" {
  description = "Per-environment Actions secrets, keyed by environment name then secret name."
  type        = map(map(string))
  default     = {}
  sensitive   = true
}
