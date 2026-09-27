# Custom-mode VPC: subnet ranges are declared explicitly rather than created automatically.
resource "google_compute_network" "platform" {
  project = var.project_id
  name    = "${local.name_prefix}-vpc"

  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}

resource "google_compute_subnetwork" "platform_private" {
  project = var.project_id
  name    = "${local.name_prefix}-private-subnet"
  region  = var.gcp_region

  ip_cidr_range            = local.private_subnet_cidr
  network                  = google_compute_network.platform.id
  private_ip_google_access = true

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}
