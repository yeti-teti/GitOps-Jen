resource "google_compute_instance" "jenkins-server" {
  boot_disk {
    auto_delete = true
    device_name = "jenkins-server"

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-minimal-2404-noble-amd64-v20250523"
      size  = 10
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src           = "vm_add-tf"
    goog-ops-agent-policy = "v2-x86-template-1-4-0"
  }

  machine_type = "e2-standard-2"

  metadata = {
    enable-osconfig = "TRUE"
    # startup-script  = "#!/bin/bash\n# Installations for Ubuntu 22.04\n# Java\nsudo apt update -y\nsudo apt install openjdk-17-jre -y\nsudo apt install openjdk-17-jdk -y\njava --version\n\n# Jenkins\ncurl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \\\n  /usr/share/keyrings/jenkins-keyring.asc > /dev/null\necho deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \\\n  https://pkg.jenkins.io/debian binary/ | sudo tee \\\n  /etc/apt/sources.list.d/jenkins.list > /dev/null\nsudo apt-get update -y\nsudo apt-get install jenkins -y\n\n# Docker\nsudo apt update\nsudo apt install docker.io -y\nsudo usermod -aG docker jenkins\nsudo usermod -aG docker ubuntu\nsudo systemctl restart docker\nsudo chmod 777 /var/run/docker.sock\n\n# Container for Jenkins (Optional)\n# docker run -d -p 8080:8080 -p 50000:50000 --name jenkins-container jenkins/jenkins:lts\n\n# Docker Container of Sonarqube\ndocker run -d  --name sonar -p 9000:9000 sonarqube:lts-community\n\n# GCP CLI\nsudo apt-get install apt-transport-https ca-certificates gnupg\necho \"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main\" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list\ncurl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.gpg\nsudo apt-get update && sudo apt-get install google-cloud-cli\n\n# kubectl\nsudo apt update\nsudo apt install curl -y\nsudo curl -LO \"https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl\"\nsudo chmod +x kubectl\nsudo mv kubectl /usr/local/bin/\nkubectl version --client\n\n# Terraform\nwget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg\necho \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list\nsudo apt update\nsudo apt install terraform -y\n\n# Trivy\nsudo apt-get install wget apt-transport-https gnupg lsb-release -y\nwget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -\necho deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list\nsudo apt update\nsudo apt install trivy -y\n\n# Helm\nsudo snap install helm --classic\n"
  }

  name = "jenkins-server"

  network_interface {
    access_config {
      # Static external IP
      nat_ip       = "" 
      network_tier = "PREMIUM"
    }

    # Static Internal IP
    network_ip  = ""
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/exalted-crane-459000-g5/regions/us-central1/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "16519852651-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  zone = "us-central1-a"
}

module "ops_agent_policy" {
  source        = "github.com/terraform-google-modules/terraform-google-cloud-operations/modules/ops-agent-policy"
  project       = "exalted-crane-459000-g5"
  zone          = "us-central1-a"
  assignment_id = "goog-ops-agent-v2-x86-template-1-4-0-us-central1-a"
  agents_rule = {
    package_state = "installed"
    version       = "latest"
  }
  instance_filter = {
    all = false
    inclusion_labels = [{
      labels = {
        goog-ops-agent-policy = "v2-x86-template-1-4-0"
      }
    }]
  }
}

resource "google_compute_firewall" "allow-jenkins" {
  name = "allow-jenkins"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["22", "80", "8080", "9000", "50000"]
  }
  
  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["jenkins-server"]
}