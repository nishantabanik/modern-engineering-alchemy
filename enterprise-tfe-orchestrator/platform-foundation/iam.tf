# ---------------------------------------------------------------------------
# IAM & Workload Identity Configuration
# Connects GKE ServiceAccounts directly to Google Cloud without static keys.
# ---------------------------------------------------------------------------

# 1. Custom Service Account for GKE Nodes (Least-Privilege)
resource "google_service_account" "gke_node" {
  project      = var.project_id
  account_id   = "${local.name_prefix}-gke-node-sa"
  display_name = "GKE Node Service Account for ${var.env}"
}

locals {
  gke_node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset(local.gke_node_roles)

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# ---------------------------------------------------------------------------
# 2. External Secrets Operator (ESO) Workload Identity
# Allows the ESO Pod inside GKE to read secrets from GCP Secret Manager
# ---------------------------------------------------------------------------
resource "google_service_account" "external_secret_operator" {
  project      = var.project_id
  account_id   = "external-secret-operator"
  display_name = "Service Account for External Secret Operator"
}

resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secret_operator.email}"
}

resource "google_service_account_iam_binding" "eso_workload_identity" {
  service_account_id = google_service_account.external_secret_operator.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
  ]

  depends_on = [google_container_cluster.platform_cluster]
}

# ---------------------------------------------------------------------------
# 3. Flux CD Image Reflector Workload Identity
# Allows Flux in GKE to scan Google Artifact Registry for new container tags
# ---------------------------------------------------------------------------
resource "google_service_account" "flux_image_reflector" {
  project      = var.project_id
  account_id   = "flux-image-reflector"
  display_name = "Service Account for Flux Image Reflector Controller"
}

resource "google_project_iam_member" "flux_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.flux_image_reflector.email}"
}

resource "google_service_account_iam_binding" "flux_workload_identity" {
  service_account_id = google_service_account.flux_image_reflector.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[flux-system/image-reflector-controller]"
  ]

  depends_on = [google_container_cluster.platform_cluster]
}
