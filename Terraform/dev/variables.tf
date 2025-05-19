variable "project_id" {
  description = "GCP Project ID"
  default     = "exalted-crane-459000-g5"
}

variable "region" {
  description = "GCP Region"
  default     = "us-west1"
}

variable "zone" {
  description = "GCP Zone for zonal resources"
  default     = "us-west1-a"
}

variable "service_account_id" {
  description = "Service account ID"
  default     = "legion-project"
}
