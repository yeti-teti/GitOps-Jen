# service account
resource "google_service_account" "terraform-pyramid" {
  account_id   = "legion-project"
  display_name = "Infra to invade egypt"
}
# Binding service account with the storage admin role
resource "google_project_iam_binding" "storage-admin" {
  depends_on = [google_service_account.terraform-pyramid]
  project    = "legion-101"
  role       = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.terraform-pyramid.email}"
  ]
}
# Binding service account with compute role
resource "google_project_iam_binding" "compute-admin" {
  depends_on = [google_service_account.terraform-pyramid]
  project    = "legion-101"
  role       = "roles/compute.admin"
  members = [
    "serviceAccount:${google_service_account.terraform-pyramid.email}"
  ]
}
#Binding service account with the Container admin role
resource "google_project_iam_binding" "container-admin" {
  depends_on = [google_service_account.terraform-pyramid]
  project    = "legion-101"
  role       = "roles/container.admin"
  members = [
    "serviceAccount:${google_service_account.terraform-pyramid.email}"
  ]
}
# VPC
resource "google_compute_network" "this" {
  name                            = "vpc-legion"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
}
# SUBNETS
resource "google_compute_subnetwork" "this_public" {
  name                     = "subnetwork-vpc-legion-public"
  ip_cidr_range            = "10.10.10.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.this.id
  private_ip_google_access = false
  depends_on               = [google_compute_network.this]
}
resource "google_compute_subnetwork" "this_private" {
  name                     = "subnetwork-vpc-legion-private"
  ip_cidr_range            = "10.10.20.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.this.id
  private_ip_google_access = true
  depends_on               = [google_compute_network.this]
}
# Firewall rules
resource "google_compute_firewall" "default" {
  name    = "legion-firewall"
  network = google_compute_network.this.id

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000", "22", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
}
# NAT Router for accessing private instances in subnet
resource "google_compute_router" "this" {
  name    = "legion-router"
  region  = google_compute_subnetwork.this_private.region
  network = google_compute_network.this.id
}
resource "google_compute_router_nat" "this" {
  name                               = "legion-router-nat"
  router                             = google_compute_router.this.name
  region                             = google_compute_router.this.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.this_private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
# GKE Cluster
resource "google_container_cluster" "primary" {
  name       = "gke-cluster-egypt"
  location   = "us-central1"
  network    = google_compute_network.this.name
  subnetwork = google_compute_subnetwork.this_private.name

  remove_default_node_pool = true
  initial_node_count       = 1
  node_config {
    service_account = google_service_account.terraform-pyramid.email
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.10.30.0/28"
  }
  master_authorized_networks_config {

    cidr_blocks {
      cidr_block = format("%s/32", google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip)
      # cidr_block = "10.10.20.0/28"
    }
  }
  depends_on = [google_service_account.terraform-pyramid]
}
# Node pool for GKE
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name     = "cleo-node-pool"
  location = "us-central1"

  cluster    = google_container_cluster.primary.name
  node_count = 2
  node_locations = [
    "us-central1-a"
  ]
  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    service_account = google_service_account.terraform-pyramid.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_service_account.terraform-pyramid]
}

# Bastion resource for GKE
resource "google_compute_instance" "bastion" {
  name         = "bastion-vm-gke"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.this.self_link
    subnetwork = google_compute_subnetwork.this_public.self_link
    access_config {

    }
  }
  tags                    = ["bastion"]
  metadata_startup_script = <<-EOT
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install kubectl
  EOT
}
