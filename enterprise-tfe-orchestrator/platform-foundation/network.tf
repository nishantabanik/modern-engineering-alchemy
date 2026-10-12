# ---------------------------------------------------------------------------
# VPC Network & Subnets using official Google Cloud Network Module
# https://registry.terraform.io/modules/terraform-google-modules/network/google
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project_id
  network_name = "${local.name_prefix}-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name               = "${local.name_prefix}-private-subnet"
      subnet_ip                 = local.private_subnet_cidr
      subnet_region             = var.gcp_region
      subnet_private_access     = "true"
      subnet_flow_logs          = "true"
      subnet_flow_logs_interval = local.vpc_flow_logs_aggregation_interval
      subnet_flow_logs_sampling = tostring(local.vpc_flow_logs_sampling)
      subnet_flow_logs_metadata = local.vpc_flow_logs_metadata
    }
  ]

  secondary_ranges = {
    "${local.name_prefix}-private-subnet" = [
      {
        range_name    = local.pods_range_name
        ip_cidr_range = local.pods_secondary_cidr
      },
      {
        range_name    = local.services_range_name
        ip_cidr_range = local.services_secondary_cidr
      }
    ]
  }

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}
