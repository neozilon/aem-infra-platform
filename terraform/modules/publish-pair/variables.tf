variable "name_prefix" {
  description = "Prefix for resource names/tags, e.g. \"aem-dev\"."
  type        = string
}

variable "pair_index" {
  description = "Index of this pair (0-based) — makes names unique when count > 1."
  type        = number
  default     = 0
}

variable "vpc_id" {
  description = "VPC to place the pair in."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for both the Publish and Dispatcher instances of this pair."
  type        = string
}

variable "publish_instance_type" {
  description = "EC2 instance type for the Publish node."
  type        = string
  default     = "t3.large"
}

variable "dispatcher_instance_type" {
  description = "EC2 instance type for the Dispatcher node."
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI to use for both nodes. Empty = latest Amazon Linux 2023 x86_64."
  type        = string
  default     = ""
}

variable "publish_root_volume_size" {
  description = "Publish root volume size (GB)."
  type        = number
  default     = 30
}

variable "publish_data_volume_size" {
  description = "Publish repository data volume size (GB)."
  type        = number
  default     = 60
}

variable "publish_port" {
  description = "Publish HTTP port."
  type        = number
  default     = 4503
}

variable "author_security_group_id" {
  description = "Author SG — allowed to reach Publish for replication."
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB SG — allowed to reach the Dispatcher on port 80."
  type        = string
}

variable "binaries_bucket_id" {
  description = "Name of the S3 bucket holding the AEM binaries."
  type        = string
}

variable "binaries_bucket_arn" {
  description = "ARN of the binaries bucket (for the read policy)."
  type        = string
}

variable "quickstart_jar_key" {
  description = "S3 key of the quickstart jar."
  type        = string
}

variable "license_key" {
  description = "S3 key of the license."
  type        = string
}

variable "service_pack_key" {
  description = "S3 key of the service pack, or empty."
  type        = string
  default     = ""
}

variable "dispatcher_tar_key" {
  description = "S3 key of the dispatcher module tarball."
  type        = string
}

variable "aem_version" {
  description = "AEM version (tag/reporting)."
  type        = string
  default     = "6.6.0"
}

variable "java_version" {
  description = "Java major version to install (Corretto)."
  type        = string
  default     = "21"
}

variable "aem_env_runmode" {
  description = "Environment runmode appended to the role runmode (dev/stage/prod). Empty = role runmode only."
  type        = string
  default     = ""
}

variable "publish_jvm_opts" {
  description = "JVM options for the Publish process."
  type        = string
  default     = "-XX:+UseG1GC -Xms1024m -Xmx4096m -Djava.awt.headless=true"
}

variable "backup_tag_value" {
  description = "Value of the \"Backup\" tag for DLM volume selection."
  type        = string
  default     = "true"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
