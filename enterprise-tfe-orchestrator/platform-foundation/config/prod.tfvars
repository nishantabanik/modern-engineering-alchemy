# ---------------------------------------------------------------------------
# PROD configuration — INTENTIONALLY EMPTY (fully commented out)
#
# We are NOT creating a production GCP project right now.
# This file exists so the structure mirrors the two-environment pattern
# (dev + prod) used in industry-standard Terraform layouts.
#
# When you are ready to create prod, uncomment the block below,
# create the prod project, then set the HCP Terraform workspace
# to this file.
# ---------------------------------------------------------------------------

# project_id = "REPLACE-WITH-YOUR-PROD-PROJECT-ID"
# gcp_region = "europe-west1"
# env        = "prod"
#
# k8s_cluster_name = "lab-cluster-prod"
#
# k8s_node_pools = {
#   "primary-pool" = {
#     min_node_count = 1
#     max_node_count = 3
#     machine_type   = "e2-medium"
#     disk_type      = "pd-balanced"
#     preemptible    = false
#     labels = {
#       role = "primary"
#     }
#   }
# }
#
# secret_manager_secrets = {
#   monitoring = [
#     "grafana-creds-monitoring",
#   ]
#   common = [
#     "team-secrets",
#   ]
# }
