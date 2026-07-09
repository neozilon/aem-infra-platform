# One-time global AWS plumbing (Phase 8), applied ONCE with human credentials.
# Everything after this uses GitHub->AWS OIDC; no long-lived keys anywhere.
#   - OIDC provider + one IAM role per environment (trust scoped to this
#     repo's GitHub environment, so stage/prod approvals gate AWS access too)
#   - Terraform remote-state bucket + DynamoDB lock table
#   - Private seed bucket for the licensed AEM binaries
#   - Monthly cost budget with email alerts
# State for THIS root is local (chicken-and-egg with the state bucket).

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "owner/name of the GitHub repository allowed to assume the roles."
  type        = string
  default     = "neozilon/aem-infra-platform"
}

variable "environments" {
  description = "GitHub environments that get an AWS role."
  type        = list(string)
  default     = ["dev", "stage", "prod"]
}

variable "budget_limit_usd" {
  description = "Monthly cost budget (USD) for the alert."
  type        = string
  default     = "50"
}

variable "budget_email" {
  description = "Email notified at 80% and 100% of the budget."
  type        = string
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  state_name  = "aem-platform-tfstate-${local.account_id}"
  seed_name   = "aem-platform-binaries-seed-${local.account_id}"
  github_oidc = "token.actions.githubusercontent.com"
}

# --- GitHub OIDC -------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc}"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "assume_gha" {
  for_each = toset(var.environments)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs running in THIS repo and THIS GitHub environment may assume the
    # role — the stage/prod reviewer gates therefore also gate AWS access.
    condition {
      test     = "StringLike"
      variable = "${local.github_oidc}:sub"
      values   = ["repo:${var.github_repository}:environment:${each.value}"]
    }
  }
}

resource "aws_iam_role" "gha" {
  for_each = toset(var.environments)

  name               = "gha-aem-${each.value}"
  assume_role_policy = data.aws_iam_policy_document.assume_gha[each.value].json

  tags = { Project = "aem", Environment = each.value, ManagedBy = "terraform" }
}

# Prototype scope: the pipeline provisions entire environments, so it gets
# admin. Scoping to least-privilege per module is documented as future work.
resource "aws_iam_role_policy_attachment" "gha_admin" {
  for_each = toset(var.environments)

  role       = aws_iam_role.gha[each.value].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- Remote state ------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_name
  tags   = { Project = "aem", ManagedBy = "terraform" }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = "aem-platform-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Project = "aem", ManagedBy = "terraform" }
}

# --- Binaries seed bucket (licensed artifacts, uploaded once via CLI) --------

resource "aws_s3_bucket" "seed" {
  bucket = local.seed_name
  tags   = { Project = "aem", ManagedBy = "terraform" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "seed" {
  bucket = aws_s3_bucket.seed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "seed" {
  bucket = aws_s3_bucket.seed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Cost guardrail ----------------------------------------------------------

resource "aws_budgets_budget" "monthly" {
  name         = "aem-platform-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

# --- Outputs -----------------------------------------------------------------

output "gha_role_arns" {
  description = "Per-environment role ARNs for the AWS_ROLE_ARN GitHub variable."
  value       = { for env, role in aws_iam_role.gha : env => role.arn }
}

output "tfstate_bucket" {
  description = "Remote-state bucket (for envs/*/providers.tf backend blocks)."
  value       = aws_s3_bucket.tfstate.id
}

output "tflock_table" {
  description = "DynamoDB lock table."
  value       = aws_dynamodb_table.tflock.name
}

output "seed_bucket" {
  description = "Binaries seed bucket (BINARIES_SEED_BUCKET GitHub variable)."
  value       = aws_s3_bucket.seed.id
}
