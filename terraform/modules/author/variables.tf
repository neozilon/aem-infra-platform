variable "name_prefix" {
  description = "Prefix for resource names/tags, e.g. \"aem-dev\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the Author node in."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the Author instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Author (AEM is memory-hungry)."
  type        = string
  default     = "t3.xlarge"
}

variable "ami_id" {
  description = "AMI to use. Empty = latest Amazon Linux 2023 x86_64."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB)."
  type        = number
  default     = 30
}

variable "data_volume_size" {
  description = "Dedicated EBS data volume for the AEM repository (GB)."
  type        = number
  default     = 100
}

variable "aem_port" {
  description = "Author HTTP port."
  type        = number
  default     = 4502
}

variable "ingress_security_group_ids" {
  description = "Source security groups allowed to reach the Author port (typically the ALB SG)."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Extra CIDRs allowed to reach the Author port directly (non-prod debugging; keep tight)."
  type        = list(string)
  default     = []
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

variable "backup_bucket_arn" {
  description = "ARN of the content-package backup bucket. Non-empty = the instance role may write packages/* there (Tier-2 backups)."
  type        = string
  default     = ""
}

variable "jvm_opts" {
  description = "JVM options for the AEM process."
  type        = string
  default     = "-XX:+UseG1GC -Xms2048m -Xmx6144m -Djava.awt.headless=true"
}

variable "backup_tag_value" {
  description = "Value of the \"Backup\" tag used by the DLM snapshot policy to select this node's volumes."
  type        = string
  default     = "true"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
