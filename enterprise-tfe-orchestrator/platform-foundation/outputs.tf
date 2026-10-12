output "enabled_apis" {
  description = "APIs managed by this Terraform configuration."
  value       = sort(tolist(local.required_apis))
}

output "vpc_name" {
  description = "Name of the platform VPC."
  value       = google_compute_network.platform.name
}

output "private_subnet_name" {
  description = "Name of the platform private subnet."
  value       = google_compute_subnetwork.platform_private.name
}

output "artifact_registry_repository" {
  description = "Artifact Registry Docker repository ID."
  value       = google_artifact_registry_repository.platform_docker.repository_id
}

output "artifact_bucket_name" {
  description = "Name of the private platform artefact bucket."
  value       = google_storage_bucket.platform_artifacts.name
}

output "gke_cluster_name" {
  description = "Name of the provisioned GKE cluster."
  value       = google_container_cluster.platform_cluster.name
}

output "gke_cluster_endpoint" {
  description = "API endpoint of the GKE cluster."
  value       = google_container_cluster.platform_cluster.endpoint
}

output "gke_connect_command" {
  description = "Run this command on your Mac to connect kubectl directly to your cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.platform_cluster.name} --region ${var.gcp_region} --project ${var.project_id}"
}

