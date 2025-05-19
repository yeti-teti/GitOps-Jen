terraform {
  backend "gcs" {
    bucket = "cleo-egypt"
    prefix = "dev/terraform.tfstate"
  }
}
