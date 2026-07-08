locals {
  # Flatten { env => { key => value } } into addressable "env:key" maps so each
  # variable/secret becomes its own resource instance.
  environment_variable_pairs = {
    for pair in flatten([
      for env, vars in var.environment_variables : [
        for k, v in vars : { env = env, key = k, value = v }
      ]
    ]) : "${pair.env}:${pair.key}" => pair
  }

  # Secret *names* are not sensitive; only the values are. nonsensitive() lets
  # the names drive for_each, while each value is pulled straight from the
  # (still-sensitive) variable inside the resource.
  environment_secret_pairs = nonsensitive({
    for pair in flatten([
      for env, secrets in var.environment_secrets : [
        for k, v in secrets : { env = env, key = k }
      ]
    ]) : "${pair.env}:${pair.key}" => pair
  })
}

# Resolve reviewer usernames to the numeric IDs the environment resource needs.
data "github_user" "reviewers" {
  for_each = toset(var.environment_reviewers)
  username = each.value
}

# --- Repository -------------------------------------------------------------

resource "github_repository" "platform" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.repository_visibility

  # auto_init creates the default branch so protection/environments can attach.
  auto_init = true

  has_issues   = true
  has_projects = false
  has_wiki     = false

  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true

  topics = var.repository_topics
}

# Enable Dependabot alerts (separate resource; the repository attribute is
# deprecated in provider v6).
resource "github_repository_vulnerability_alerts" "platform" {
  repository = github_repository.platform.name
}

# --- Branch protection on the default branch --------------------------------

resource "github_branch_protection" "default" {
  repository_id  = github_repository.platform.node_id
  pattern        = var.default_branch
  enforce_admins = var.enforce_admins

  required_pull_request_reviews {
    required_approving_review_count = var.required_pr_approvals
    dismiss_stale_reviews           = true
  }

  dynamic "required_status_checks" {
    for_each = length(var.required_status_checks) > 0 ? [1] : []
    content {
      strict   = true
      contexts = var.required_status_checks
    }
  }
}

# --- Deployment environments (dev / stage / prod) ---------------------------

resource "github_repository_environment" "env" {
  for_each    = toset(var.environments)
  repository  = github_repository.platform.name
  environment = each.value

  wait_timer = each.value == "prod" ? var.prod_wait_timer : 0

  # Gated environments require reviewer approval (objective O4).
  dynamic "reviewers" {
    for_each = contains(var.protected_environments, each.value) && length(var.environment_reviewers) > 0 ? [1] : []
    content {
      users = [for u in var.environment_reviewers : data.github_user.reviewers[u].id]
    }
  }

  # Protected environments deploy only from protected branches; dev is open.
  dynamic "deployment_branch_policy" {
    for_each = contains(var.protected_environments, each.value) ? [1] : []
    content {
      protected_branches     = true
      custom_branch_policies = false
    }
  }
}

# --- Actions variables & secrets --------------------------------------------

resource "github_actions_variable" "repo" {
  for_each      = var.repository_variables
  repository    = github_repository.platform.name
  variable_name = each.key
  value         = each.value
}

resource "github_actions_secret" "repo" {
  for_each        = nonsensitive(toset(keys(var.repository_secrets)))
  repository      = github_repository.platform.name
  secret_name     = each.value
  plaintext_value = var.repository_secrets[each.value]
}

resource "github_actions_environment_variable" "env" {
  for_each      = local.environment_variable_pairs
  repository    = github_repository.platform.name
  environment   = github_repository_environment.env[each.value.env].environment
  variable_name = each.value.key
  value         = each.value.value
}

resource "github_actions_environment_secret" "env" {
  for_each        = local.environment_secret_pairs
  repository      = github_repository.platform.name
  environment     = github_repository_environment.env[each.value.env].environment
  secret_name     = each.value.key
  plaintext_value = var.environment_secrets[each.value.env][each.value.key]
}
