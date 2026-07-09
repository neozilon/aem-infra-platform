variable "project" {
  description = "Project name; part of the name prefix and tags."
  type        = string
  default     = "aem"
}

variable "environment" {
  description = "Environment name (dev/stage/prod); part of the name prefix and tags."
  type        = string
}

variable "tags" {
  description = "Extra tags merged into the standard tag set."
  type        = map(string)
  default     = {}
}

# --- Network ----------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to span."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway (cheaper; less HA)."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Create SSM interface endpoints."
  type        = bool
  default     = true
}

# --- Binaries (licensed; local paths, gitignored) ---------------------------

variable "quickstart_jar_path" {
  description = "Local path to the AEM quickstart jar."
  type        = string
}

variable "license_path" {
  description = "Local path to license.properties."
  type        = string
}

variable "dispatcher_tar_path" {
  description = "Local path to the dispatcher module tar.gz (x86_64)."
  type        = string
}

variable "service_pack_path" {
  description = "Optional local path to the LTS service pack. Empty = none."
  type        = string
  default     = ""
}

# --- Versions ----------------------------------------------------------------

variable "aem_version" {
  description = "AEM version tag."
  type        = string
  default     = "6.6.0"
}

variable "java_version" {
  description = "Java major version (Corretto)."
  type        = string
  default     = "21"
}

# --- Author ------------------------------------------------------------------

variable "author_instance_type" {
  description = "Author instance type."
  type        = string
  default     = "t3.xlarge"
}

variable "author_data_volume_size" {
  description = "Author data volume size (GB)."
  type        = number
  default     = 100
}

variable "author_allowed_cidr_blocks" {
  description = "CIDRs allowed to reach Author directly (non-prod)."
  type        = list(string)
  default     = []
}

# --- Publish pairs -----------------------------------------------------------

variable "publish_pair_count" {
  description = "Number of 1:1 Publish+Dispatcher pairs (O3 elasticity knob)."
  type        = number
  default     = 1
}

variable "publish_instance_type" {
  description = "Publish instance type."
  type        = string
  default     = "t3.large"
}

variable "dispatcher_instance_type" {
  description = "Dispatcher instance type."
  type        = string
  default     = "t3.small"
}

variable "publish_data_volume_size" {
  description = "Publish data volume size (GB)."
  type        = number
  default     = 60
}

# --- ALB ---------------------------------------------------------------------

variable "alb_internal" {
  description = "Make the ALB internal."
  type        = bool
  default     = false
}

variable "alb_allowed_cidr_blocks" {
  description = "CIDRs allowed to reach the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM cert ARN for HTTPS. Empty = HTTP-only."
  type        = string
  default     = ""
}

variable "author_host" {
  description = "Host header routing to Author via the ALB. Empty = no Author ALB route."
  type        = string
  default     = ""
}

# --- Backup ------------------------------------------------------------------

variable "backup_retention_count" {
  description = "EBS snapshots retained per volume (dev 3 / stage 7 / prod 30)."
  type        = number
  default     = 3
}

variable "snapshot_interval_hours" {
  description = "EBS snapshot interval (hours)."
  type        = number
  default     = 24
}
