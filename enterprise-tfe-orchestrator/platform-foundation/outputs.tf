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
