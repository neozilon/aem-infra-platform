# Thin env root: everything is delegated to the shared composition module so
# dev/stage/prod share one definition and differ only in <env>.tfvars.

module "aem" {
  source = "../../modules/aem-environment"

  project     = var.project
  environment = var.environment

  # Network
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway

  # Binaries
  quickstart_jar_path = var.quickstart_jar_path
  license_path        = var.license_path
  dispatcher_tar_path = var.dispatcher_tar_path
  service_pack_path   = var.service_pack_path

  # Versions
  aem_version  = var.aem_version
  java_version = var.java_version

  # Author
  author_instance_type       = var.author_instance_type
  author_data_volume_size    = var.author_data_volume_size
  author_allowed_cidr_blocks = var.author_allowed_cidr_blocks

  # Publish pairs (O3 elasticity via publish_pair_count)
  publish_pair_count       = var.publish_pair_count
  publish_instance_type    = var.publish_instance_type
  dispatcher_instance_type = var.dispatcher_instance_type
  publish_data_volume_size = var.publish_data_volume_size

  # ALB
  alb_internal            = var.alb_internal
  alb_allowed_cidr_blocks = var.alb_allowed_cidr_blocks
  certificate_arn         = var.certificate_arn
  author_host             = var.author_host

  # Backup
  backup_retention_count  = var.backup_retention_count
  snapshot_interval_hours = var.snapshot_interval_hours
}
