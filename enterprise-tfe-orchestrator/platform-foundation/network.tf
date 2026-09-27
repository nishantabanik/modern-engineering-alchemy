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

  # Required by the GCP organization policy for new subnets.
  # A 100% sampling rate satisfies ESSENTIAL, LIGHT, and COMPREHENSIVE policies.
  log_config {
    aggregation_interval = local.vpc_flow_logs_aggregation_interval
    flow_sampling        = local.vpc_flow_logs_sampling
    metadata             = local.vpc_flow_logs_metadata
  }

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}
