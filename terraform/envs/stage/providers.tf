terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state — enable in Phase 8 once the AWS account and a state bucket
  # (+ DynamoDB lock table) exist. Local state is used until then so the roots
  # can be built and validated without cloud access.
  #
  # backend "s3" {
  #   bucket         = "aem-platform-tfstate"
  #   key            = "envs/stage/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "aem-platform-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
}
