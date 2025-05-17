variable "project_id" {
  description = "GCP Project ID"
  default     = "exalted-crane-459000-g5"
}

variable "region" {
  description = "GCP Region"
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone for zonal resources"
  default     = "us-central1-a"
}

variable "service_account_id" {
  description = "Service account ID"
  default     = "legion-project"
}

variable "network_name" {
  description = "VPC Network name"
  default     = "vpc-legion"
}

variable "cluster_name" {
  description = "GKE Cluster name"
  default     = "gke-cluster-egypt"
}
