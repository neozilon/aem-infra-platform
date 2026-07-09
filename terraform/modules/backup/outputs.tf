output "dlm_policy_id" {
  description = "DLM lifecycle policy ID."
  value       = aws_dlm_lifecycle_policy.ebs.id
}

output "package_bucket_id" {
  description = "Content-package backup bucket name (empty if not created)."
  value       = var.create_package_bucket ? aws_s3_bucket.packages[0].id : ""
}

output "package_bucket_arn" {
  description = "Content-package backup bucket ARN (empty if not created)."
  value       = var.create_package_bucket ? aws_s3_bucket.packages[0].arn : ""
}
