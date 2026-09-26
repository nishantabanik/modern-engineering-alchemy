project_id = "mms-clp-playground-1790326573"
gcp_region = "europe-west1"
env        = "dev"

k8s_cluster_name = "dev-gke-cluster"

k8s_node_pools = {
  "primary-pool" = {
    min_node_count = 1
    max_node_count = 3
    machine_type   = "e2-micro"
    disk_type      = "pd-balanced"
    preemptible    = false
    labels = {
      role = "primary"
    }
  }
}

# Stage -> list of Secret Manager secret names.
# Terraform creates the empty envelopes only. Values are added by a human later.
secret_manager_secrets = {
  monitoring = [
    "grafana-creds-monitoring",
  ]
  common = [
    "team-secrets",
  ]
}
