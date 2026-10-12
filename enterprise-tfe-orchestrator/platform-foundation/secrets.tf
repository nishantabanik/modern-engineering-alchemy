# ---------------------------------------------------------------------------
# Google Cloud Secret Manager Envelopes
# Creates the empty secret envelopes in GCP Secret Manager.
# Values are added securely by human operators or external pipelines.
# ---------------------------------------------------------------------------

locals {
  # Flatten the map of stages -> secret list into a list of objects
  all_secrets = flatten([
    for stage, secret_list in var.secret_manager_secrets : [
      for secret_name in secret_list : {
        stage = stage
        name  = secret_name
      }
    ]
  ])
}

resource "google_secret_manager_secret" "envelopes" {
  for_each = { for s in local.all_secrets : s.name => s }

  project   = var.project_id
  secret_id = each.key

  labels = merge(
    local.common_labels,
    {
      stage = each.value.stage
    }
  )

  replication {
    auto {}
  }

  depends_on = [google_project_service.required["secretmanager.googleapis.com"]]
}
