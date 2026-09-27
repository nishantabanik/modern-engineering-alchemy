# Private bucket for platform artefacts. It does not contain application secrets.
resource "google_storage_bucket" "platform_artifacts" {
  project                     = var.project_id
  name                        = local.artifact_bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.common_labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required["storage.googleapis.com"]]
}
