# Env-root variables. These files are IDENTICAL across dev/stage/prod — the
# environments differ ONLY in their <env>.tfvars values.

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name."
  type        = string
  default     = "aem"
}

variable "environment" {
  description = "Environment name (dev/stage/prod)."
  type        = string
}

# --- Network ----------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "az_count" {
  type    = number
  default = 2
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}

# --- Binaries (local paths relative to the env root) ------------------------
variable "quickstart_jar_path" {
  type    = string
  default = "../../../binaries/cq-quickstart-6.6.0.jar"
}
variable "license_path" {
  type    = string
  default = "../../../binaries/license.properties"
}
variable "dispatcher_tar_path" {
  type    = string
  default = "../../../binaries/dispatcher-apache2.4-linux-x86_64-ssl3.0-4.3.8.tar.gz"
}
variable "service_pack_path" {
  type    = string
  default = ""
}

# --- Versions ----------------------------------------------------------------
variable "aem_version" {
  type    = string
  default = "6.6.0"
}
variable "java_version" {
  type    = string
  default = "21"
}

# --- Author ------------------------------------------------------------------
variable "author_instance_type" {
  type    = string
  default = "t3.xlarge"
}
variable "author_data_volume_size" {
  type    = number
  default = 100
}
variable "author_allowed_cidr_blocks" {
  type    = list(string)
  default = []
}

# --- Publish pairs -----------------------------------------------------------
variable "publish_pair_count" {
  type    = number
  default = 1
}
variable "publish_instance_type" {
  type    = string
  default = "t3.large"
}
variable "dispatcher_instance_type" {
  type    = string
  default = "t3.small"
}
variable "publish_data_volume_size" {
  type    = number
  default = 60
}

# --- ALB ---------------------------------------------------------------------
variable "alb_internal" {
  type    = bool
  default = false
}
variable "alb_allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "author_host" {
  type    = string
  default = ""
}

# --- Backup ------------------------------------------------------------------
variable "backup_retention_count" {
  type    = number
  default = 3
}
variable "snapshot_interval_hours" {
  type    = number
  default = 24
}
