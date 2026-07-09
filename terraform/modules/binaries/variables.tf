variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"aem\" (bucket gets a random suffix for global uniqueness)."
  type        = string
}

variable "bucket_name" {
  description = "Explicit bucket name. Empty = \"<name_prefix>-binaries-<random>\"."
  type        = string
  default     = ""
}

variable "quickstart_jar_path" {
  description = "Local path to the AEM quickstart jar (licensed; gitignored). Uploaded to s3://<bucket>/<quickstart_jar_key>."
  type        = string
}

variable "quickstart_jar_key" {
  description = "S3 key for the quickstart jar."
  type        = string
  default     = "aem/cq-quickstart.jar"
}

variable "license_path" {
  description = "Local path to license.properties."
  type        = string
}

variable "license_key" {
  description = "S3 key for the license."
  type        = string
  default     = "aem/license.properties"
}

variable "dispatcher_tar_path" {
  description = "Local path to the dispatcher module tar.gz (x86_64 ssl3.0 build for AWS)."
  type        = string
}

variable "dispatcher_tar_key" {
  description = "S3 key for the dispatcher tarball."
  type        = string
  default     = "dispatcher/dispatcher-apache2.4-linux-x86_64.tar.gz"
}

variable "service_pack_path" {
  description = "Optional local path to the LTS service pack content package. Empty = none uploaded."
  type        = string
  default     = ""
}

variable "service_pack_key" {
  description = "S3 key for the service pack."
  type        = string
  default     = "aem/service-pack.zip"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
