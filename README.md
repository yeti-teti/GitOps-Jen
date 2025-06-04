# Scalable and Fault-Tolerant CI/CD Pipeline for Kubernetes on GCP

## Architecture Overview
![CI/CD Pipeline Flow Diagram](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*CMSHt3p1wqK7u7cUQEsz7A.jpeg)

This project implements a complete DevSecOps CI/CD pipeline using Jenkins, Terraform, ArgoCD, and GKE with integrated security scanning and monitoring.

## Prerequisites

- GCP account with billing enabled
- GitHub repository with your application code
- Basic knowledge of Kubernetes, Docker, and Terraform
- `gcloud` CLI installed and configured locally

## Implementation Steps

### 1. Setup GitHub Repository

- Fork or create your application repository
- Ensure your code includes Dockerfile and Kubernetes manifests
- Generate a Personal Access Token for Jenkins integration
- Configure repository webhooks for CI/CD automation

### 2. Create VM Instance in GCP

#### Option A: Manual Setup
```bash
# Create VM instance with minimum specifications:
# - Machine type: e2-standard-4 (4 vCPUs, 16GB RAM)
# - Boot disk: Ubuntu 20.04 LTS, 50GB SSD
# - Allow HTTP/HTTPS traffic in firewall settings
```

- Go to GCP Console > Compute Engine > VM Instances
- Configure networking and security settings
- **Important:** Setup static IP for the VM to avoid routing issues with dynamic IPs
- Run the installation script:
  ```bash
  bash Jenkins/startup-script.sh
  ```
- Add firewall rules:
  ```bash
  # Jenkins access
  gcloud compute firewall-rules create jenkins-rule --allow tcp:8080 --source-ranges 0.0.0.0/0
  
  # SonarQube access  
  gcloud compute firewall-rules create sonarqube-rule --allow tcp:9000 --source-ranges 0.0.0.0/0
  ```

#### Option B: Terraform Automation
```bash
cd Terraform/Jen
terraform init
terraform plan
terraform apply
```

**Note:** You can uncomment the startup script in Terraform configuration to automatically install Jenkins, Docker, etc., or run the Ansible playbook separately: `Ansible/GKE-VM.yaml`

**Important:** May need to increase the boot disk size based on your application requirements.

### 3. Configure Jenkins

#### Initial Setup
```bash
# Access Jenkins at: http://<VM_EXTERNAL_IP>:8080
# Get initial admin password:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### Required Credentials
Add the following in Jenkins Dashboard > Manage Jenkins > Credentials:

- **GCP Service Account:** 
  - Kind: Secret file
  - Upload the JSON key file
  - ID: `gcp-service-account`
  
- **GitHub Credentials:**
  - Kind: Secret text
  - Secret: Your GitHub Personal Access Token
  - ID: `github-token`
  
- **Docker Registry (Artifact Registry):**
  - Kind: Username with password
  - ID: `docker-registry`

#### Required Plugins
Install these plugins via Manage Jenkins > Plugin Manager:
- Docker Pipeline
- Terraform
- SonarQube Scanner
- NodeJS
- OWASP Dependency-Check
- Kubernetes CLI
- Pipeline: Stage View

#### Pipeline Setup
- Create new pipeline job
- Use pipeline script from `Jenkins/pipeline-terraform`
- Configure GitHub webhook for automatic builds
- Set up build triggers and notifications

### 4. Deploy GKE Cluster using Terraform

Navigate to terraform configuration:
```bash
cd Terraform/dev
terraform init
terraform plan
terraform apply
```

#### Created Resources
The Terraform scripts will create:
- **Service Account** with required IAM roles:
  - Container Admin Role
  - Compute Admin Role  
  - Storage Admin Role
- **VPC Network** with custom subnets and proper CIDR ranges
- **NAT Gateway** and Cloud Router for outbound connectivity
- **Private GKE Cluster** with:
  - Master authorized networks
  - Private nodes with IP aliasing
  - Network policy enabled
  - Workload Identity enabled
- **Bastion Host** for secure cluster access

### 5. Configure Bastion Host

#### SSH Access
```bash
# SSH into bastion host
gcloud compute ssh bastion-host --zone=<ZONE> --project=<PROJECT_ID>
```

#### Tool Installation
```bash
# Option 1: Manual installation
bash Utils/kubectl.sh
bash Utils/helm.sh

# Option 2: Automated with Ansible
ansible-playbook Ansible/bastion-play.yaml
```

#### GKE Cluster Connection
```bash
# Authenticate with GCP
gcloud auth login

# Get cluster credentials
gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-name>

# Verify connection
kubectl get nodes
kubectl get pods -n kube-system
```

#### Workload Identity Setup
```bash
# Create Kubernetes service account
kubectl create serviceaccount <gke-service-account-name> -n kube-system

# Annotate GKE SA with GCP SA
kubectl annotate serviceaccount <gke-service-account-name> -n kube-system \
  iam.gke.io/gcp-service-account=<gke-service-account-name>@<PROJECT_ID>.iam.gserviceaccount.com

# Install Helm
bash Utils/helm.sh

# Create cluster admin binding
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin --user=<YOUR-USER-ID>
```

### 6. Install and Configure ArgoCD

#### Installation
```bash
# Install ArgoCD using utility script
bash Utils/argo.sh

# Or use Ansible playbook
ansible-playbook Ansible/bastion-play.yaml --tags argocd
```

#### Access Configuration
```bash
# Get ArgoCD admin password
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGO_PWD"

# Port forward to access UI (run this in background)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

- Default username: `admin`
- Access UI at: `https://localhost:8080`
- **Important:** Change default password after first login

### 7. Setup GCP Artifact Registry

#### Create Repositories
```bash
# Create repositories for your applications
gcloud artifacts repositories create <frontend-repo> --repository-format=docker --location=<region>
gcloud artifacts repositories create <backend-repo> --repository-format=docker --location=<region>

# Configure Docker authentication
gcloud auth configure-docker <region>-docker.pkg.dev
```

#### Jenkins Integration
Add the following credentials in Jenkins:
- **Artifact Registry URI:** Kind: Secret Text
- **GCP Project ID:** Kind: Secret Text  
- **Application Image Names:** Kind: Secret Text for each service

### 8. Install and Configure SonarQube for DevSecOps

#### Installation
```bash
# SSH into the Jenkins VM
# Install SonarQube
bash Utils/sq.sh

# Or use Ansible
ansible-playbook Ansible/GKE-VM.yaml --tags sonarqube
```

- Add firewall rule for SonarQube if not present (PORT 9000)
- Access SonarQube at: `http://<jenkins-server-ip>:9000`
- Default credentials: `admin/admin`

#### Configuration Steps

1. **Generate Authentication Token:**
   - Login > Administration > Security > Users > Tokens > Generate Token
   - **Important:** Keep the token safe - you'll need it for Jenkins

2. **Configure Webhook for Jenkins Integration:**
   - Administration > Configuration > Webhooks > Create
   - URL: `http://<jenkins-server-public-ip>:8080/sonarqube-webhook/`

3. **Create Project:**
   - Projects > Create Project > Manually 
   - Provide project details > Locally > Use existing token
   - Select "Other" and "Linux" as OS

4. **Jenkins Integration:**
   
   **Add Credentials in Jenkins:**
   - SonarQube Token: Kind: Secret Text
   - GCP Project ID: Kind: Secret Text
   - Image repository names: Kind: Secret Text

   **Configure SonarQube Server in Jenkins:**
   - Dashboard > Manage Jenkins > Configure System > SonarQube Servers
   - Name: `sonarqube` (must match pipeline configuration)
   - Server URL: `http://<jenkins-vm-ip>:9000`
   - Authentication Token: Select the SonarQube token credential

   **Configure Global Tools:**
   - Manage Jenkins > Global Tool Configuration
   - SonarQube Scanner: Install automatically
   - OWASP Dependency-Check: Install automatically from GitHub

### 9. Required Jenkins Plugins Configuration

Ensure these plugins are installed and configured:

**Essential Plugins:**
- Docker (for container operations)
- Docker Commons
- Docker Pipeline  
- Docker API
- docker-build-step
- Eclipse Temurin installer (for Java builds)
- NodeJS (for frontend builds)
- OWASP Dependency-Check (security scanning)
- SonarQube Scanner (code quality)
- Python (for Python applications)
- Pipeline: Stage View
- Blue Ocean (enhanced UI)

### 10. Setup Monitoring for GKE Cluster

#### Install Prometheus and Grafana
```bash
# SSH into Bastion Host
# Install monitoring stack
bash Utils/promANDGrad.sh

# Or use Ansible
ansible-playbook Ansible/bastion-play.yaml --tags monitoring
```

#### Access Monitoring Dashboards
```bash
# Prometheus (metrics collection)
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Grafana (visualization)
kubectl port-forward svc/grafana -n monitoring 3000:80
# Default Grafana credentials: admin/admin
```

### 11. Deploy Applications using ArgoCD

#### Repository Connection
1. **Connect Repository in ArgoCD UI:**
   - Settings > Repositories > Connect Repo via HTTPS
   - Repository URL: `https://github.com/<username>/<repo>`
   - Username: `<github-username>`
   - Password: `<github-token>`

#### Application Deployment
2. **Create Kubernetes Namespace:**
   ```bash
   kubectl create namespace <app-namespace>
   ```

3. **Create Application Secrets:**
   ```bash
   # Example for API keys
   kubectl create secret generic api-secrets \
     -n <app-namespace> \
     --from-literal=openai-api-key="<your-api-key>"
   ```

4. **Create ArgoCD Application:**
   - Applications > New App > Fill application details
   - **Repository:** Your connected GitHub repository  
   - **Path:** Directory where Kubernetes manifests are present (e.g., `k8s/frontend`, `k8s/backend`)
   - **Destination:** Your GKE cluster
   - **Namespace:** Target namespace for deployment

5. **Configure Image Pull Authentication:**
   ```bash
   # SSH to GKE nodes for Artifact Registry authentication
   gcloud compute ssh --zone "<zone>" "<node-name>" \
     --project "<project-id>" --internal-ip
   
   # Configure Docker authentication on nodes
   gcloud auth configure-docker <region>-docker.pkg.dev
   ```
   
   **Important:** Ensure image URLs in your manifests match the Artifact Registry format:
   ```
   <region>-docker.pkg.dev/<project-id>/<repository>/<image>:<tag>
   ```

### 12. External Access Configuration

#### Option A: GCE Managed Ingress (Recommended for GCP)
- Use Google Cloud Load Balancer with managed SSL certificates
- Configure ingress with `kubernetes.io/ingress.class: "gce"`

#### Option B: NGINX Ingress Controller
```bash
# Install NGINX Ingress Controller
bash Utils/nginx.sh

# Verify installation
kubectl get pods -n ingress-nginx

# Create ingress resources for your applications
kubectl apply -f k8s/ingress/
```

## Troubleshooting Common Issues

### Jenkins Build Failures
```bash
# Check Jenkins service status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Verify Docker daemon
sudo systemctl status docker
```

### GKE Connectivity Issues
```bash
# Test cluster connectivity
kubectl cluster-info

# Check node status
kubectl get nodes -o wide

# Verify pod networking
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
```

### ArgoCD Application Sync Issues
```bash
# Check application status
kubectl get applications -n argocd

# Manual sync if needed
argocd app sync <app-name>

# Check pod logs
kubectl logs -f deployment/<app-name> -n <namespace>
```

### Image Pull Errors
- Verify Artifact Registry authentication on all nodes
- Check image URLs in deployment manifests
- Ensure service account has proper IAM permissions

## Security Best Practices

- Use private GKE clusters with authorized networks
- Enable Workload Identity for secure pod-to-GCP communication  
- Implement Network Policies for pod-to-pod communication
- Regular security scanning with SonarQube and OWASP
- Use least-privilege IAM roles and service accounts
- Enable audit logging and monitoring
- Rotate credentials regularly

## Maintenance Tasks

- **Weekly:** Update Jenkins plugins and scan for security vulnerabilities
- **Monthly:** Update GKE cluster and node pools
- **Quarterly:** Review and rotate service account keys
- **As needed:** Scale cluster based on resource utilization

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)

## Support

For issues and troubleshooting:
1. Check the troubleshooting section above
2. Review application and infrastructure logs
3. Consult official documentation for each tool
4. Open an issue in this repository with detailed error information