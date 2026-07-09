variable "name_prefix" {
  description = "Prefix for resource names/tags, e.g. \"aem-dev\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
}

variable "internal" {
  description = "Make the ALB internal (no public IP)."
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to reach the ALB (dev/stage should be restricted)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Empty = HTTP-only listener (demo/dev without a domain)."
  type        = string
  default     = ""
}

variable "author_host" {
  description = "Host header that routes to the Author target group (host-based rule). Empty = no Author routing on the ALB."
  type        = string
  default     = ""
}

variable "author_port" {
  description = "Author target port."
  type        = number
  default     = 4502
}

variable "dispatcher_port" {
  description = "Dispatcher target port."
  type        = number
  default     = 80
}

variable "dispatcher_health_check_path" {
  description = "Health-check path for the Dispatcher target group."
  type        = string
  default     = "/"
}

variable "author_health_check_path" {
  description = "Health-check path for the Author target group."
  type        = string
  default     = "/libs/granite/core/content/login.html"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
