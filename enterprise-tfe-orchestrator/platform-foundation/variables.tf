# ---------------------------------------------------------------------------
# REQUIRED PARAMETERS
# Values MUST be supplied in ./config/{env}.tfvars
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID that holds the platform infrastructure"
  type        = string
}

variable "gcp_region" {
  description = "Default GCP region for regional resources"
  type        = string
}

variable "env" {
  description = "Product environment (dev or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be either dev or prod."
  }
}

# ---------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These have sensible defaults and can be overridden in config/{env}.tfvars
# ---------------------------------------------------------------------------

variable "k8s_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "lab-cluster"
}

variable "k8s_node_pools" {
  description = "Node pools to create on the GKE cluster"
  type = map(
    object({
      min_node_count = number
      max_node_count = number
      machine_type   = string
      disk_type      = string
      preemptible    = optional(bool, false)
      labels         = optional(map(string), {})
    })
  )
  default = {}
}

variable "secret_manager_secrets" {
  description = "Map of stage -> list of Secret Manager secret names to create (envelope only, no values)"
  type        = map(list(string))
  default     = {}
}
