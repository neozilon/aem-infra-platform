output "alb_dns_name" {
  description = "Public DNS name of the ALB — the site entry point."
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "author_instance_id" {
  description = "Author EC2 instance ID."
  value       = module.author.instance_id
}

output "author_private_ip" {
  description = "Author private IP."
  value       = module.author.private_ip
}

output "publish_instance_ids" {
  description = "Publish EC2 instance IDs (per pair)."
  value       = module.publish_pair[*].publish_instance_id
}

output "dispatcher_instance_ids" {
  description = "Dispatcher EC2 instance IDs (per pair)."
  value       = module.publish_pair[*].dispatcher_instance_id
}

output "publish_pair_count" {
  description = "Number of Publish:Dispatcher pairs deployed."
  value       = var.publish_pair_count
}

output "binaries_bucket" {
  description = "Name of the binaries S3 bucket."
  value       = module.binaries.bucket_id
}

output "package_backup_bucket" {
  description = "Name of the content-package backup bucket."
  value       = module.backup.package_bucket_id
}
