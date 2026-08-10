variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "db_password" {
  type        = string
  description = "QM Database Password"
  sensitive   = true
}

variable "gcp_region" {
  type        = string
  description = "GCP Region"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP Zone"
  default     = "us-central1-a"
}

variable "domain_name" {
  type        = string
  description = "Domain name for Caddy automatic HTTPS reverse proxy"
  default     = "joe.gentleweapons.xyz"
}

