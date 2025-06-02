# Bastion resource for GKE
resource "google_compute_address" "bastion_static_ip" {
  project = var.project_id
  name    = "${var.project_id}-bastion-static-ip"
  region  = var.region
}

resource "google_compute_instance" "bastion" {
  project      = var.project_id
  name         = "${var.project_id}-bastion-vm-gke"
  machine_type = "e2-medium"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.subnet_public.self_link
    access_config {
      nat_ip = google_compute_address.bastion_static_ip.address
    }
  }
  tags                    = ["bastion"]
  metadata_startup_script = <<-EOT
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y kubectl
  sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
  EOT
}

# GKE
variable "gke_num_nodes" {
  type        = number
  default     = 1
  description = "number of gke nodes"
}

# GKE cluster
data "google_container_engine_versions" "gke_version" {
  project        = var.project_id
  location       = var.region
  version_prefix = "1.27."
}

resource "google_container_cluster" "primary" {
  project                  = var.project_id
  name                     = "${var.project_id}-gke"
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet_private.name
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  node_config {
    machine_type = "e2-medium"
    disk_type    = "pd-standard"
    disk_size_gb = 50
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name     = "${google_container_cluster.primary.name}-main-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  version    = data.google_container_engine_versions.gke_version.release_channel_default_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    # machine_type = "n1-standard-1"
    machine_type = "e2-medium"
    tags         = ["gke-node", "${var.project_id}-gke"]
    disk_type    = "pd-standard"
    disk_size_gb = 50
    metadata = {
      disable-legacy-endpoints = "true"
      # enable-oslogin = "true"
    }
  }
}
