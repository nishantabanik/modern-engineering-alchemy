# Private Docker registry for platform and workload container images.
resource "google_artifact_registry_repository" "platform_docker" {
  project       = var.project_id
  location      = var.gcp_region
  repository_id = local.artifact_registry_repository_id
  description   = "Private Docker images for the ${var.env} platform environment"
  format        = "DOCKER"
  labels        = local.common_labels

  depends_on = [google_project_service.required["artifactregistry.googleapis.com"]]
}
