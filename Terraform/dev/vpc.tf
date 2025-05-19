# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet Public Bastion and NAT
resource "google_compute_subnetwork" "subnet_public" {
  name          = "${var.project_id}-subnet-public"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Subnet Private (For nodes)
resource "google_compute_subnetwork" "subnet_private" {
  name          = "${var.project_id}-subnet-private"
  region        = var.region
  network       = google_compute_network.vpc.id
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

# NAT ROUTER
resource "google_compute_router" "router" {
  name    = "${var.project_id}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_id}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.subnet_private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall Rules

# Firewall Rule for SSH to Bastion
resource "google_compute_firewall" "allow_ssh_to_bastion" {
  name    = "${var.project_id}-allow-ssh-bastion"
  network = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["bastion"]
  source_ranges = ["0.0.0.0/0"]
}

# Firewall rule for GKE internal nodes communication
resource "google_compute_firewall" "allow_internal_gke" {
  name    = "${var.project_id}-allow-internal-gke"
  network = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_tags = ["gke-node"]
  target_tags = ["gke-node"]
}

# For egress to internet from nodes (via NAT):
resource "google_compute_firewall" "allow_egress_from_private_subnet" {
  name    = "${var.project_id}-allow-egress-private"
  network = google_compute_network.vpc.self_link
  allow {
    protocol = "all" # Allows all protocols
  }
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["gke-node"]
  direction          = "EGRESS"
}
