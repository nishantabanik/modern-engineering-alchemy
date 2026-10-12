# ---------------------------------------------------------------------------
# Cloud NAT using official Google Cloud NAT Module
# https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google
# ---------------------------------------------------------------------------

module "cloud_nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.2"

  project_id    = var.project_id
  region        = var.gcp_region
  router        = "${local.name_prefix}-router"
  network       = module.vpc.network_name
  create_router = true
  name          = "${local.name_prefix}-nat"

  log_config_enable = true
  log_config_filter = "ERRORS_ONLY"

  depends_on = [module.vpc]
}
