# ---------------------------------------------------------------------------
# Cloud Router and Cloud NAT
# Required for private GKE nodes to access external registries, GitHub,
# Helm repositories, and external APIs without needing public IP addresses.
# ---------------------------------------------------------------------------

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${local.name_prefix}-router"
  network = google_compute_network.platform.id
  region  = var.gcp_region

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}

resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = "${local.name_prefix}-nat"
  router  = google_compute_router.router.name
  region  = var.gcp_region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_compute_router.router]
}
