# Shared values for the first platform-foundation layer.
locals {
  name_prefix = "platform-${var.env}"

  common_labels = {
    environment = var.env
    managed_by  = "terraform"
    component   = "platform-foundation"
  }

  private_subnet_cidr             = "10.10.0.0/24"
  artifact_registry_repository_id = "${local.name_prefix}-docker"
  artifact_bucket_name            = "${var.project_id}-${local.name_prefix}-artifacts"

  required_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudapis.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "networkservices.googleapis.com",
    "oslogin.googleapis.com",
    "pubsub.googleapis.com",
    "replicapool.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}
