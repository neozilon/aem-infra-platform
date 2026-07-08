# Bootstrap root — creates the platform repository from a GitHub token (O1).
# Uses only the GitHub provider; no cloud credentials required at this stage.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.2"
    }
  }
}

provider "github" {
  # Token also honoured from GITHUB_TOKEN; passed here via TF_VAR_github_token.
  owner = var.github_owner
  token = var.github_token
}
