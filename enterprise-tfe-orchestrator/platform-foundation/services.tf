# Enable the APIs needed by the platform foundation and future GKE services.
resource "google_project_service" "required" {
  for_each = local.required_apis

  project = var.project_id
  service = each.value

  # Removing this Terraform resource must not unexpectedly disable a project API.
  disable_on_destroy = false
}
