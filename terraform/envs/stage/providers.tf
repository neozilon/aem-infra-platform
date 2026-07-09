terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state: PARTIAL configuration — bucket/key/region/lock table are
  # injected by the pipeline via -backend-config (derived from the AWS account
  # ID at runtime), so no account-specific value lives in the repo.
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
