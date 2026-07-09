locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "network" {
  source = "../network"

  name_prefix                = local.name_prefix
  vpc_cidr                   = var.vpc_cidr
  az_count                   = var.az_count
  single_nat_gateway         = var.single_nat_gateway
  enable_interface_endpoints = var.enable_interface_endpoints
  tags                       = local.tags
}

module "binaries" {
  source = "../binaries"

  name_prefix         = local.name_prefix
  quickstart_jar_path = var.quickstart_jar_path
  license_path        = var.license_path
  dispatcher_tar_path = var.dispatcher_tar_path
  service_pack_path   = var.service_pack_path
  tags                = local.tags
}

module "alb" {
  source = "../alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  internal            = var.alb_internal
  allowed_cidr_blocks = var.alb_allowed_cidr_blocks
  certificate_arn     = var.certificate_arn
  author_host         = var.author_host
  tags                = local.tags
}

module "author" {
  source = "../author"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  subnet_id                  = module.network.private_subnet_ids[0]
  instance_type              = var.author_instance_type
  data_volume_size           = var.author_data_volume_size
  ingress_security_group_ids = [module.alb.security_group_id]
  allowed_cidr_blocks        = var.author_allowed_cidr_blocks

  binaries_bucket_id  = module.binaries.bucket_id
  binaries_bucket_arn = module.binaries.bucket_arn
  quickstart_jar_key  = module.binaries.quickstart_jar_key
  license_key         = module.binaries.license_key
  service_pack_key    = module.binaries.service_pack_key

  aem_version     = var.aem_version
  java_version    = var.java_version
  aem_env_runmode = var.environment

  # Tier-2 backups: the Author uploads content packages here.
  backup_bucket_write_enabled = true
  backup_bucket_arn           = module.backup.package_bucket_arn

  tags = local.tags
}

module "publish_pair" {
  source = "../publish-pair"
  count  = var.publish_pair_count

  name_prefix              = local.name_prefix
  pair_index               = count.index
  vpc_id                   = module.network.vpc_id
  subnet_id                = element(module.network.private_subnet_ids, count.index)
  publish_instance_type    = var.publish_instance_type
  dispatcher_instance_type = var.dispatcher_instance_type
  publish_data_volume_size = var.publish_data_volume_size

  author_security_group_id = module.author.security_group_id
  alb_security_group_id    = module.alb.security_group_id

  binaries_bucket_id  = module.binaries.bucket_id
  binaries_bucket_arn = module.binaries.bucket_arn
  quickstart_jar_key  = module.binaries.quickstart_jar_key
  license_key         = module.binaries.license_key
  service_pack_key    = module.binaries.service_pack_key
  dispatcher_tar_key  = module.binaries.dispatcher_tar_key

  aem_version     = var.aem_version
  java_version    = var.java_version
  aem_env_runmode = var.environment
  tags            = local.tags
}

module "backup" {
  source = "../backup"

  name_prefix             = local.name_prefix
  retention_count         = var.backup_retention_count
  snapshot_interval_hours = var.snapshot_interval_hours
  tags                    = local.tags
}

# --- ALB target-group attachments (here, not in the alb module, to avoid a
#     module cycle: author/publish depend on the ALB SG; the ALB depends on
#     their instance IDs) ----------------------------------------------------

resource "aws_lb_target_group_attachment" "author" {
  count            = var.author_host != "" ? 1 : 0
  target_group_arn = module.alb.author_target_group_arn
  target_id        = module.author.instance_id
  port             = 4502
}

resource "aws_lb_target_group_attachment" "dispatcher" {
  count            = var.publish_pair_count
  target_group_arn = module.alb.dispatcher_target_group_arn
  target_id        = module.publish_pair[count.index].dispatcher_instance_id
  port             = 80
}
