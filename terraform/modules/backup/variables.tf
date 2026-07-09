variable "name_prefix" {
  description = "Prefix for resource names/tags, e.g. \"aem-dev\"."
  type        = string
}

variable "target_tags" {
  description = "Tags a volume must carry to be captured by the DLM snapshot policy (matches the Backup tag set on Author/Publish volumes)."
  type        = map(string)
  default     = { Backup = "true" }
}

variable "snapshot_interval_hours" {
  description = "Snapshot interval in hours (DLM allows 1,2,3,4,6,8,12,24)."
  type        = number
  default     = 24

  validation {
    condition     = contains([1, 2, 3, 4, 6, 8, 12, 24], var.snapshot_interval_hours)
    error_message = "snapshot_interval_hours must be one of 1,2,3,4,6,8,12,24."
  }
}

variable "snapshot_time" {
  description = "UTC time of day for the first snapshot, HH:MM."
  type        = string
  default     = "03:00"
}

variable "retention_count" {
  description = "Number of snapshots to retain per volume (dev 3 / stage 7 / prod 30)."
  type        = number
  default     = 3
}

variable "create_package_bucket" {
  description = "Create the versioned S3 bucket for content-package backups (Tier 2)."
  type        = bool
  default     = true
}

variable "package_bucket_name" {
  description = "Explicit package-backup bucket name. Empty = \"<name_prefix>-pkg-backup-<random>\"."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Purge all object versions on destroy. Keep FALSE in prod (backups outlive the env)."
  type        = bool
  default     = false
}
