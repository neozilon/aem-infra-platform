variable "name_prefix" {
  description = "Prefix for resource names/tags, e.g. \"aem-dev\"."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span (public + private subnet per AZ)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets reach the internet (AEM package downloads, OS updates)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper; less HA). Recommended for dev/stage."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Create SSM interface VPC endpoints so Session Manager works without a NAT/bastion."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
