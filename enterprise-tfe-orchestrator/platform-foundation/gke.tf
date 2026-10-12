# ---------------------------------------------------------------------------
# GKE Private Cluster using official Google Kubernetes Engine Module
# https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/private-cluster
# ---------------------------------------------------------------------------

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 33.0"

  project_id = var.project_id
  name       = "${local.name_prefix}-${var.k8s_cluster_name}"
  region     = var.gcp_region
  regional   = true
  network    = module.vpc.network_name
  subnetwork = module.vpc.subnets_names[0]

  ip_range_pods     = local.pods_range_name
  ip_range_services = local.services_range_name

  # Creates least-privilege service account for worker nodes automatically
  create_service_account = true
  service_account_name   = "${local.name_prefix}-gke-node-sa"
  grant_registry_access  = true

  # Private nodes with accessible public control-plane endpoint for your workstation
  enable_private_endpoint = false
  enable_private_nodes    = true
  master_ipv4_cidr_block  = "172.24.0.0/28"

  gateway_api_config = {
    channel = "CHANNEL_STANDARD"
  }

  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1

  # Cost-optimized: Starts with 1 node, can scale to 0 (sleep) or up to 3 (load)
  node_pools = [
    {
      name               = "primary-pool"
      machine_type       = lookup(try(var.k8s_node_pools["primary-pool"], {}), "machine_type", "e2-standard-2")
      min_count          = 0
      max_count          = 3
      initial_node_count = 1
      auto_repair        = true
      auto_upgrade       = true
      disk_size_gb       = 50
      disk_type          = lookup(try(var.k8s_node_pools["primary-pool"], {}), "disk_type", "pd-balanced")
      preemptible        = false
    }
  ]

  node_pools_labels = {
    all = local.common_labels
    primary-pool = {
      role = "primary"
    }
  }

  node_pools_tags = {
    all = ["gke-node", "${local.name_prefix}-gke"]
  }

  depends_on = [
    module.vpc,
    module.cloud_nat,
    google_project_service.required["container.googleapis.com"],
  ]
}
