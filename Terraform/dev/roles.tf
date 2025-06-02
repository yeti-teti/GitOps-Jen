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

# Using Workload Identity
# # Google Service Account for the applications
# resource "google_service_account" "workload_identity_sa" {
#   account_id   = "${var.project_id}-wi-sa"
#   display_name = "Workload Identity Service Account"
#   project      = var.project_id
# }

# # Grant necessary permissions
# resource "google_project_iam_member" "workload_identity_sa_roles" {
#   for_each = toset([
#     "roles/artifactregistry.reader",
#     "roles/storage.objectViewer",
#     "roles/monitoring.metricWriter",
#     "roles/logging.logWriter"
#   ])
  
#   project = var.project_id
#   role    = each.value
#   member  = "serviceAccount:${google_service_account.workload_identity_sa.email}"
# }

# # Enable Workload Identity binding
# resource "google_service_account_iam_member" "workload_identity_binding" {
#   service_account_id = google_service_account.workload_identity_sa.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:${var.project_id}.svc.id.goog[default/my-k8s-service-account]"
# }