output "enabled_apis" {
  description = "APIs managed by this Terraform configuration."
  value       = sort(tolist(local.required_apis))
}

output "vpc_name" {
  description = "Name of the platform VPC."
  value       = module.vpc.network_name
}

output "private_subnet_name" {
  description = "Name of the platform private subnet."
  value       = module.vpc.subnets_names[0]
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
  value       = module.gke.name
}

output "gke_cluster_endpoint" {
  description = "API endpoint of the GKE cluster."
  value       = module.gke.endpoint
  sensitive   = true
}

output "gke_connect_command" {
  description = "Run this command on your Mac to connect kubectl directly to your cluster."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.gcp_region} --project ${var.project_id}"
}

output "eso_service_account_email" {
  description = "GCP Service Account for External Secrets Operator Workload Identity."
  value       = module.workload_identity_eso.gcp_service_account_email
}

output "flux_image_reflector_email" {
  description = "GCP Service Account for Flux Image Reflector Workload Identity."
  value       = module.workload_identity_flux.gcp_service_account_email
}
