provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = "${env.WORKSPACE}/Terraform/dev/credentials.json"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}
