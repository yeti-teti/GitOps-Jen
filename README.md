# Scalable and Fault Tolerant CI/CD pipeline for Kubernetes setup on GCP


# Flow Diagram


# Steps


### Setup Github Repo

### Create VM instance in GCP
Manual:
- Go to GCP console and create and configure compute engine vm instance
- Run the script Jenkins/startup-script.sh to install required tools
- Add firewall rule for Jenkins(PORT: 8080)
- Note: You should setup static ip for the VM Instances as Dynamics instances can cause routing issues which can cause problems when using Jenkins
Using Terraform:
- Run the Script inside Terraform/Jen

### Configure Jenkins
Manual:
- Add GCP service account credentials
- Add github credentials
- Install Terraform adn other required plugins
- Create the pipeline for setup GCP. (Jenkins/pipeline-terraform)

### Deploy the GKE Cluster using Terraform
- Create the required resources (Files presnet in Terraform/dev)
  - Service Account with the Container Admin Role, Compute Admin Role, Storage Admin Role.
  - Creation of VPC with subnets
  - NAT gateway and router
  - Private GKE Cluster
  - Bastion host

### Configure Bastion Host
- SSH into bastion host
- Install kubectl (Utils/kubectl.sh)
- Login into gcloud: gcloud auth login
- Connect to GKE cluster: gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-name>
- Check connection: kubectl get pods -n kube-system
- Create a service account in the GCP and annotate that service account
- kubectl create sa <service-account-name> -n kube-system
- Annotat GKE SA with GCP SA:
  - kubectl annotate serviceaccount <gke-service-account-name> -n kube-system iam.gke.io/gcp-service-account=<gke-service-account-name>@<PROJECT_ID>.iam.gserviceaccount.com
- Install Helm: (Utils/helm.sh)
- Create clusterbinding role
  - kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=<YOUR-USER-ID>

### Install and Configure ArgoCD
- Run and get the IP and password for ArgoCD
- Default username is admin

### Create GCP Artifact Repositories
- Create required Repositories

---
### Configure Sonarqube for the DevSecOps Pipeline
- Run (Utils/sq.sh)
- Add firewall rule for Sonarqube in GCP (PORT 9000)
### Install the required plugins and Configure the plugins to deploy the applicaiton
- Plugins
  - Docker
  - Docker Commons
  - Docker Pipeline
  - Docker API
  - docker-build-step
  - Eclipse Temurin installer
  - NodeJS
  - OWASP Dependency-Check
  - SonarQube Scanner
  - python
---

### Setup Monitoring for the GKE Cluster
-
