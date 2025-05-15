# Service account
resource "google_service_account" "terraform-pyramid" {
  account_id   = var.service_account_id
  display_name = "Infra to invade egypt"
}

# IAM Bindings for Service Account
resource "google_project_iam_binding" "storage-admin" {
  project    = var.project_id
  role       = "roles/storage.admin"
  members    = ["serviceAccount:${google_service_account.terraform-pyramid.email}"]
  depends_on = [google_service_account.terraform-pyramid]
}

resource "google_project_iam_binding" "compute-admin" {
  project    = var.project_id
  role       = "roles/compute.admin"
  members    = ["serviceAccount:${google_service_account.terraform-pyramid.email}"]
  depends_on = [google_service_account.terraform-pyramid]
}

resource "google_project_iam_binding" "container-admin" {
  project    = var.project_id
  role       = "roles/container.admin"
  members    = ["serviceAccount:${google_service_account.terraform-pyramid.email}"]
  depends_on = [google_service_account.terraform-pyramid]
}

# VPC Network
resource "google_compute_network" "this" {
  name                            = var.network_name
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
}

# Subnets
resource "google_compute_subnetwork" "this_public" {
  name                     = "${var.network_name}-public"
  ip_cidr_range            = "10.10.10.0/24"
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = false
}

resource "google_compute_subnetwork" "this_private" {
  name                     = "${var.network_name}-private"
  ip_cidr_range            = "10.10.20.0/24"
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true
}

# Firewall Rules
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

# Allow GKE Master to communicate with Kubelets on nodes
resource "google_compute_firewall" "gke_master_to_nodes_kubelet" {
  name        = "${var.network_name}-gke-master-to-nodes-kubelet"
  network     = google_compute_network.this.id
  project     = var.project_id # Good practice to specify project
  description = "Allow GKE master to connect to kubelets on TCP 10250"
  priority    = 1000 # Default priority, adjust if needed

  allow {
    protocol = "tcp"
    ports    = ["10250"] # Kubelet API port
  }

  source_ranges = [google_container_cluster.primary.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["gke-gke-cluster-egypt-4d4d7b3a-node"]
}
# Allow GKE Master for webhooks
resource "google_compute_firewall" "gke_master_to_nodes_webhooks" {
  name        = "${var.network_name}-gke-master-to-nodes-webhooks"
  network     = google_compute_network.this.id
  project     = var.project_id
  description = "Allow GKE master to connect to node webhooks on TCP 443 (and others if needed)"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["443", "15017"] // Common ports for webhooks, adjust as needed
  }
  source_ranges = [google_container_cluster.primary.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["gke-gke-cluster-egypt-4d4d7b3a-node"]
}
# Allow traffic within the GKE node subnet
resource "google_compute_firewall" "gke_nodes_internal_communication" {
  name        = "${var.network_name}-gke-nodes-internal"
  network     = google_compute_network.this.id
  project     = var.project_id
  description = "Allow all traffic between nodes in the GKE private subnet"
  priority    = 1000

  allow {
    protocol = "all"
  }

  // Allow traffic from any node in the private subnet to any other node in the private subnet.
  source_ranges = [google_compute_subnetwork.this_private.ip_cidr_range]
}

resource "google_compute_firewall" "gke_nodes_to_master_api" {
  name        = "${var.network_name}-gke-nodes-to-master"
  network     = google_compute_network.this.id
  project     = var.project_id
  description = "Allow GKE nodes to connect to GKE master API server"
  priority    = 900

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges      = [google_compute_subnetwork.this_private.ip_cidr_range]
  destination_ranges = [google_container_cluster.primary.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags        = ["gke-gke-cluster-egypt-4d4d7b3a-node"]
}


# NAT Router for accessing private instances in subnet
resource "google_compute_router" "this" {
  name    = "legion-router"
  region  = var.region
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

# Bastion resource for GKE
resource "google_compute_instance" "bastion" {
  name         = "bastion-vm-gke"
  machine_type = "e2-medium"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.this.self_link
    subnetwork = google_compute_subnetwork.this_public.self_link
    access_config {}
  }
  tags                    = ["bastion"]
  metadata_startup_script = <<-EOT
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y kubectl
  sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
  EOT
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name       = var.cluster_name
  location   = var.region
  network    = google_compute_network.this.name
  subnetwork = google_compute_subnetwork.this_private.name

  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    service_account = google_service_account.terraform-pyramid.email
    disk_type       = "pd-standard" // Explicitly set to standard disk
    disk_size_gb    = 30
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.10.30.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = format("%s/32", google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip)
    }
  }

  depends_on = [google_service_account.terraform-pyramid]
}

# Node pool for GKE
resource "google_container_node_pool" "primary_nodes" {
  name     = "cleo-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  node_count     = 2
  node_locations = [var.zone]

  node_config {
    preemptible     = false
    machine_type    = "e2-standard-2"
    service_account = google_service_account.terraform-pyramid.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_type       = "pd-standard"
    disk_size_gb    = 50
  }

  depends_on = [google_container_cluster.primary]
}
