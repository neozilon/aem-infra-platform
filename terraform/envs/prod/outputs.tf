output "alb_dns_name" {
  description = "Site entry point (ALB DNS)."
  value       = module.aem.alb_dns_name
}

output "author_instance_id" {
  value = module.aem.author_instance_id
}

output "publish_instance_ids" {
  value = module.aem.publish_instance_ids
}

output "dispatcher_instance_ids" {
  value = module.aem.dispatcher_instance_ids
}

output "publish_pair_count" {
  value = module.aem.publish_pair_count
}

output "binaries_bucket" {
  value = module.aem.binaries_bucket
}

output "package_backup_bucket" {
  value = module.aem.package_backup_bucket
}
