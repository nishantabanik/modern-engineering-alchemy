# ---------------------------------------------------------------------------
# Google Kubernetes Engine (GKE) Cluster & Autoscaling Node Pool
# Cost-optimized: Starts with 1 node, scales up to 3 nodes only on load.
# ---------------------------------------------------------------------------

resource "google_container_cluster" "platform_cluster" {
  project  = var.project_id
  name     = "${local.name_prefix}-${var.k8s_cluster_name}"
  location = var.gcp_region

  # We manage the node pool separately to allow clean lifecycle management.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.platform.id
  subnetwork = google_compute_subnetwork.platform_private.id

  # VPC-Native Cluster configuration
  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_range_name
    services_secondary_range_name = local.services_range_name
  }

  # Private Cluster settings
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Allows direct kubectl access from your workstation
    master_ipv4_cidr_block  = "172.24.0.0/28"
  }

  # Enable Gateway API (matches the enterprise architecture)
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Workload Identity allows Kubernetes ServiceAccounts to act as GCP IAM ServiceAccounts
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Cost-saving defaults: Disable expensive addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = false

  depends_on = [
    google_project_service.required["container.googleapis.com"],
    google_compute_subnetwork.platform_private,
    google_compute_router_nat.nat,
  ]
}

# ---------------------------------------------------------------------------
# Lightweight Autoscaling Node Pool
# Default: 1 node (e2-standard-2). Autoscales to 2 or 3 nodes if load increases.
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "primary_nodes" {
  project    = var.project_id
  name       = "primary-pool"
  cluster    = google_container_cluster.platform_cluster.name
  location   = var.gcp_region

  initial_node_count = 1

  autoscaling {
    min_node_count  = 0
    max_node_count  = 3
    location_policy = "BALANCED"
  }

  node_config {
    machine_type = lookup(
      try(var.k8s_node_pools["primary-pool"], {}),
      "machine_type",
      "e2-standard-2"
    )
    disk_type = lookup(
      try(var.k8s_node_pools["primary-pool"], {}),
      "disk_type",
      "pd-balanced"
    )
    disk_size_gb = 50
    preemptible  = false

    service_account = google_service_account.gke_node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(
      local.common_labels,
      {
        role = "primary"
      }
    )

    tags = ["gke-node", "${local.name_prefix}-gke"]

    # Shielded GKE nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_container_cluster.platform_cluster,
    google_project_iam_member.gke_node_roles,
  ]
}
