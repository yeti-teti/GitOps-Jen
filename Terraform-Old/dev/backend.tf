terraform {
  backend "gcs" {
    bucket = "cleo-egypt"
    prefix = "dev/terraform.tfstate"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}
