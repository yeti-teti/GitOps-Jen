variable "project_id" {
  description = "project_id"
}
variable "region" {
  description = "region"
}
provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet (VPC Native mode)
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24" # Primary range for nodes
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/14" # Large range for pods
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20" # Range for services
  }
}
