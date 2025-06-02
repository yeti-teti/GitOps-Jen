# Scalable and Fault Tolerant CI/CD pipeline for Kubernetes setup on GCP

## Flow Diagram
![CI/CD Pipeline Flow Diagram](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*CMSHt3p1wqK7u7cUQEsz7A.jpeg)

## Steps

### Setup Github Repo

### Create VM instance in GCP

**Manual:**
- Go to GCP console and create and configure compute engine vm instance
- Run the script `Jenkins/startup-script.sh` to install required tools
- Add firewall rule for Jenkins (PORT: 8080)
- Note: You should setup static ip for the VM Instances as Dynamics instances can cause routing issues which can cause problems when using Jenkins

**Using Terraform:**
- Run the Script inside `Terraform/Jen`
- Note: You can uncomment the script to run the config to install jenkins, docker etc..
- Or Run the ansible playbook from your environment. (`Ansible/GKE-VM.yaml`)

### Configure Jenkins

**Manual:**
- Add GCP service account credentials
- Add github credentials
- Install Terraform and other required plugins
- Create the pipeline for setup GCP. (`Jenkins/pipeline-terraform`)

### Deploy the GKE Cluster using Terraform

- Create the required resources (Files present in `Terraform/dev`)
  - Service Account with the Container Admin Role, Compute Admin Role, Storage Admin Role.
  - Creation of VPC with subnets
  - NAT gateway and router
  - Private GKE Cluster
  - Bastion host

### Configure Bastion Host

- SSH into bastion host
- **Bastion Setup:**
  - Install kubectl (`Utils/kubectl.sh` or `Ansible/bastion-play.yaml`)
  - Login into gcloud: 
    ```bash
    gcloud auth login
    ```
  - Connect to GKE cluster: 
    ```bash
    gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-name>
    ```
  - Check connection: 
    ```bash
    kubectl get pods -n kube-system
    ```
  - Create a service account in the GCP and annotate that service account
    ```bash
    kubectl create sa <gke-service-account-name> -n kube-system
    ```
  - Annotate GKE SA with GCP SA:
    ```bash
    kubectl annotate serviceaccount <gke-service-account-name> -n kube-system iam.gke.io/gcp-service-account=<gke-service-account-name>@<PROJECT_ID>.iam.gserviceaccount.com
    ```
  - Install Helm: (`Utils/helm.sh` or `Ansible/bastion-play.yaml`)
  - Create clusterbinding role:
    ```bash
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=<YOUR-USER-ID>
    ```

### Install and Configure ArgoCD

- Run and get the IP and password for ArgoCD (`Utils/argo.sh`)
- Default username is `admin`
- To get the default password: 
  ```bash
  echo "$ARGO_PWD"
  ```

### Create GCP Artifact Repositories

- Create required Repositories (Manually in GCP)
- Add credentials in Jenkins (Secret-Text)
- Add the Repo names

### Install and Configure Sonarqube for the DevSecOps Pipeline

**Installation:**
- SSH into the VM with jenkins installed
- Run (`Utils/sq.sh`) or (`Ansible/GKE-VM.yaml`)
- Add firewall rule for Sonarqube in GCP if not present (PORT 9000)

**Configuration:**
- Login > Administration > Security > Users > Update Tokens > Generate the tokens
- Keep the tokens safe
- Add the tokens in credentials in Jenkins
- Configure the webhooks:
  - Administration > Configuration > Webhooks > Create
  - `http://<jenkins-server-public-ip>:8080/sonarqube-webhook/`
- Create Projects (Based on your repo):
  - Projects > Create Project > Manually > Provide details > Locally > Select Use existing token > Continue > Select Other and Linux as OS
- Add Sonar Credentials on jenkins:
  - Go to jenkins
  - Dashboard > Manage Jenkins > Credentials
  - Select Secret Text and paste Secret and create
- Add the GCP Account ID in Jenkins (Because of the Artifact registry repo URI):
  - Kind: Secret Text
  - Paste your GCP Account ID in secret and create
- Add GCP Artifact image name based on your repo:
  - Eg: Select Secret text and paste your frontend repo name in secret and create
- **In Jenkins:**
  - Add Sonar server in System config:
    - Name should be same as in pipeline
    - Server same as jenkins with port 9000
    - Auth Token same as ID in credentials
  - Add sonar tool in Global Tools:
    - Name same as tool name in pipeline
    - Install Automatically
  - Add OWASP in Global Tool Config:
    - Install Automatically
    - Install from github

### Install the required plugins and Configure the plugins to deploy the application in Jenkins

**Plugins:**
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

### Setup Monitoring for the GKE Cluster

- SSH Into Bastion Host
- Run `Utils/promANDGrad.sh` or `Ansible/bastion-play.yaml`

### Deploy using ArgoCD

- Connect Repo: Setting > REPO > VIA HTTP/HTTPS > Provide URL, Username, Password (Access Token)
- Create ns in k8s
- Create Application: Applications > Create > Fill and provide the directory where the manifests are present (eg: for frontend or backend)
- Add Image pull auth from Artifact registry in k8s nodes to allow it to pull images
  - gcloud compute ssh --zone "<zone>" "<node-name>" --project "<project-id>" --internal-ip