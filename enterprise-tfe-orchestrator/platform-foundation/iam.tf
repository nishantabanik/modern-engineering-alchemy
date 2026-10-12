# ---------------------------------------------------------------------------
# Workload Identity using official Google GKE Workload Identity Submodule
# https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/workload-identity
# ---------------------------------------------------------------------------

# 1. External Secrets Operator (ESO) Workload Identity
# Connects Kubernetes 'external-secrets/external-secrets' to GCP Secret Manager
module "workload_identity_eso" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 43.0"

  project_id          = var.project_id
  name                = "external-secret-operator"
  namespace           = "external-secrets"
  k8s_sa_name         = "external-secrets"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
  roles               = ["roles/secretmanager.secretAccessor"]

  depends_on = [module.gke]
}

# 2. Flux CD Image Reflector Workload Identity
# Connects Kubernetes 'flux-system/image-reflector-controller' to Google Artifact Registry
module "workload_identity_flux" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 43.0"

  project_id          = var.project_id
  name                = "flux-image-reflector"
  namespace           = "flux-system"
  k8s_sa_name         = "image-reflector-controller"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
  roles               = ["roles/artifactregistry.reader"]

  depends_on = [module.gke]
}
