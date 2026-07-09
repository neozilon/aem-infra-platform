locals {
  package_bucket_name = var.package_bucket_name != "" ? var.package_bucket_name : "${var.name_prefix}-pkg-backup-${random_id.suffix.hex}"
}

# --- Tier 1: EBS snapshots via Data Lifecycle Manager ------------------------

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name_prefix        = "${var.name_prefix}-dlm-"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "ebs" {
  description        = "${var.name_prefix} AEM EBS snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "daily"

      create_rule {
        interval      = var.snapshot_interval_hours
        interval_unit = "HOURS"
        times         = [var.snapshot_time]
      }

      retain_rule {
        count = var.retention_count
      }

      tags_to_add = merge(var.tags, {
        SnapshotCreator = "dlm"
        Name            = "${var.name_prefix}-auto-snapshot"
      })

      copy_tags = true
    }

    target_tags = var.target_tags
  }

  tags = var.tags
}

# --- Tier 2: versioned S3 bucket for content-package backups -----------------

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "packages" {
  count  = var.create_package_bucket ? 1 : 0
  bucket = local.package_bucket_name
  # Purge on destroy for ephemeral envs (dev/stage); prod passes false.
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.package_bucket_name })
}

resource "aws_s3_bucket_versioning" "packages" {
  count  = var.create_package_bucket ? 1 : 0
  bucket = aws_s3_bucket.packages[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "packages" {
  count  = var.create_package_bucket ? 1 : 0
  bucket = aws_s3_bucket.packages[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "packages" {
  count  = var.create_package_bucket ? 1 : 0
  bucket = aws_s3_bucket.packages[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
