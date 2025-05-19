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
