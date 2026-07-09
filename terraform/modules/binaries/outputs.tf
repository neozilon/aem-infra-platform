output "bucket_id" {
  description = "Name of the binaries bucket."
  value       = aws_s3_bucket.binaries.id
}

output "bucket_arn" {
  description = "ARN of the binaries bucket (grant read to instance roles)."
  value       = aws_s3_bucket.binaries.arn
}

output "quickstart_jar_key" {
  description = "S3 key of the quickstart jar."
  value       = var.quickstart_jar_key
}

output "license_key" {
  description = "S3 key of the license."
  value       = var.license_key
}

output "dispatcher_tar_key" {
  description = "S3 key of the dispatcher tarball."
  value       = var.dispatcher_tar_key
}

output "service_pack_key" {
  description = "S3 key of the service pack, or empty if none uploaded."
  value       = var.service_pack_path != "" ? var.service_pack_key : ""
}
