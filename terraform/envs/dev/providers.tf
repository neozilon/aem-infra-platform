terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state (Phase 8): bucket/table created by terraform/global.
  backend "s3" {
    bucket         = "aem-platform-tfstate-599526349046"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aem-platform-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
