locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.name_prefix}-binaries-${random_id.suffix.hex}"

  # Only upload the service pack when a path is supplied.
  base_objects = {
    quickstart = { key = var.quickstart_jar_key, source = var.quickstart_jar_path }
    license    = { key = var.license_key, source = var.license_path }
    dispatcher = { key = var.dispatcher_tar_key, source = var.dispatcher_tar_path }
  }
  service_pack_object = var.service_pack_path != "" ? {
    service_pack = { key = var.service_pack_key, source = var.service_pack_path }
  } : {}
  objects = merge(local.base_objects, local.service_pack_object)
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "binaries" {
  bucket = local.bucket_name
  # Env buckets are reproducible (re-synced from the seed bucket); allow
  # destroy to purge versions so `terraform destroy` is one-shot.
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_versioning" "binaries" {
  bucket = aws_s3_bucket.binaries.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "binaries" {
  bucket = aws_s3_bucket.binaries.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "binaries" {
  bucket = aws_s3_bucket.binaries.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any non-TLS access to the licensed artifacts.
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.binaries.arn, "${aws_s3_bucket.binaries.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "binaries" {
  bucket = aws_s3_bucket.binaries.id
  policy = data.aws_iam_policy_document.tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.binaries]
}

resource "aws_s3_object" "binary" {
  for_each = local.objects

  bucket = aws_s3_bucket.binaries.id
  key    = each.value.key
  source = each.value.source
  # etag forces re-upload when the local file changes.
  etag = filemd5(each.value.source)

  tags = var.tags
}
