#!/usr/bin/env bash
# Bootstrap GCP Workload Identity Federation for the Terraform Cloud workspace.
#
# Usage:
#   export TFC_TOKEN="<Terraform Cloud user or team API token>"
#   ./scripts/bootstrap-tfc-gcp.sh <new-gcp-project-id>
#
# Prerequisites: gcloud, curl, jq, and an authenticated GCP administrator.
# This script makes GCP and Terraform Cloud changes; it does not run terraform apply.

set -euo pipefail

TARGET_PROJECT_ID="${1:-}"
# GCP_IDENTITY_PROJECT_ID is a GCP project, not a Terraform Cloud identifier.
# TFC_IDENTITY_PROJECT_ID is retained only for compatibility with an earlier name.
IDENTITY_PROJECT_ID="${GCP_IDENTITY_PROJECT_ID:-${TFC_IDENTITY_PROJECT_ID:-$TARGET_PROJECT_ID}}"
REGION="${GCP_REGION:-europe-west1}"
ENVIRONMENT="${TF_ENVIRONMENT:-dev}"
TFC_HOSTNAME="${TFC_HOSTNAME:-app.terraform.io}"
TFC_ORGANIZATION_NAME="${TFC_ORGANIZATION_NAME:-enterprise-tfe-orchestrator}"
TFC_WORKSPACE_ID="${TFC_WORKSPACE_ID:-ws-HbPUo3znoyosCBgv}"
POOL_ID="${TFC_GCP_POOL_ID:-tfc-pool}"
PROVIDER_ID="${TFC_GCP_PROVIDER_ID:-tfc-provider}"
SERVICE_ACCOUNT_ID="${TFC_GCP_SERVICE_ACCOUNT_ID:-tfc-platform-foundation}"
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Support the canonical repository-level script and the copy beside the
# Terraform configuration without constructing the directory twice.
if [[ -f "${SCRIPT_DIRECTORY}/config/dev.tfvars" ]]; then
  DEV_TFVARS_FILE="${SCRIPT_DIRECTORY}/config/dev.tfvars"
else
  REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
  DEV_TFVARS_FILE="${REPOSITORY_ROOT}/enterprise-tfe-orchestrator/platform-foundation/config/dev.tfvars"
fi

usage() {
  echo "Usage: TFC_TOKEN=<token> $0 <new-gcp-project-id>" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

[[ -n "$TARGET_PROJECT_ID" ]] || usage
[[ -n "${TFC_TOKEN:-}" ]] || {
  echo "TFC_TOKEN must be set. Do not save this token in Git." >&2
  exit 1
}
[[ -f "$DEV_TFVARS_FILE" ]] || {
  echo "Expected Terraform variables file was not found: ${DEV_TFVARS_FILE}" >&2
  exit 1
}

require_command gcloud
require_command curl
require_command jq

tfc_api() {
  curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer ${TFC_TOKEN}" \
    --header "Content-Type: application/vnd.api+json" \
    "https://${TFC_HOSTNAME}/api/v2$1"
}

upsert_tfc_variable() {
  local key="$1"
  local value="$2"
  local category="$3"
  local description="$4"
  local variables variable_id payload

  variables="$(tfc_api "/workspaces/${TFC_WORKSPACE_ID}/vars")"
  variable_id="$(jq -r --arg key "$key" --arg category "$category" \
    '.data[] | select(.attributes.key == $key and .attributes.category == $category) | .id' \
    <<<"$variables" | head -n 1)"
  payload="$(jq -nc \
    --arg key "$key" \
    --arg value "$value" \
    --arg category "$category" \
    --arg description "$description" \
    '{data: {type: "vars", attributes: {key: $key, value: $value, category: $category, description: $description, hcl: false, sensitive: false}}}')"

  if [[ -n "$variable_id" ]]; then
    payload="$(jq --arg id "$variable_id" '.data.id = $id' <<<"$payload")"
    curl --fail-with-body --silent --show-error \
      --header "Authorization: Bearer ${TFC_TOKEN}" \
      --header "Content-Type: application/vnd.api+json" \
      --request PATCH \
      --data "$payload" \
      "https://${TFC_HOSTNAME}/api/v2/workspaces/${TFC_WORKSPACE_ID}/vars/${variable_id}" >/dev/null
  else
    curl --fail-with-body --silent --show-error \
      --header "Authorization: Bearer ${TFC_TOKEN}" \
      --header "Content-Type: application/vnd.api+json" \
      --request POST \
      --data "$payload" \
      "https://${TFC_HOSTNAME}/api/v2/workspaces/${TFC_WORKSPACE_ID}/vars" >/dev/null
  fi
}

delete_workspace_variable_if_present() {
  local key="$1"
  local variables variable_id

  variables="$(tfc_api "/workspaces/${TFC_WORKSPACE_ID}/vars")"
  variable_id="$(jq -r --arg key "$key" \
    '.data[] | select(.attributes.key == $key and .attributes.category == "env") | .id' \
    <<<"$variables" | head -n 1)"

  if [[ -n "$variable_id" ]]; then
    curl --fail-with-body --silent --show-error \
      --header "Authorization: Bearer ${TFC_TOKEN}" \
      --request DELETE \
      "https://${TFC_HOSTNAME}/api/v2/workspaces/${TFC_WORKSPACE_ID}/vars/${variable_id}" >/dev/null
  fi
}

echo "Checking the GCP projects and Terraform Cloud workspace..."
gcloud projects describe "$TARGET_PROJECT_ID" --format="value(projectNumber)" >/dev/null
gcloud projects describe "$IDENTITY_PROJECT_ID" --format="value(projectNumber)" >/dev/null
TFC_ORGANIZATION_ID="$(tfc_api "/organizations/${TFC_ORGANIZATION_NAME}" | jq -r '.data.id')"
[[ "$TFC_ORGANIZATION_ID" != "null" && -n "$TFC_ORGANIZATION_ID" ]] || {
  echo "Could not read Terraform Cloud organization ${TFC_ORGANIZATION_NAME}." >&2
  exit 1
}

echo "Enabling bootstrap APIs in the identity project..."
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  serviceusage.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project="$IDENTITY_PROJECT_ID"

# The target needs this API before the main Terraform workspace can manage its
# full API list. The identity project holds the long-lived trust resources.
gcloud services enable serviceusage.googleapis.com --project="$TARGET_PROJECT_ID"

IDENTITY_PROJECT_NUMBER="$(gcloud projects describe "$IDENTITY_PROJECT_ID" --format="value(projectNumber)")"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_ID}@${IDENTITY_PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$IDENTITY_PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_ID" \
    --project="$IDENTITY_PROJECT_ID" \
    --display-name="Terraform Cloud platform foundation"
fi

if ! gcloud iam workload-identity-pools describe "$POOL_ID" \
  --project="$IDENTITY_PROJECT_ID" \
  --location="global" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$IDENTITY_PROJECT_ID" \
    --location="global" \
    --display-name="Terraform Cloud pool"
fi

# HashiCorp guarantees the subject format and recommends validating it here.
# The exact workspace restriction is enforced separately by the service-account
# IAM binding below, which grants impersonation only to this workspace ID.
ATTRIBUTE_MAPPING="google.subject=assertion.terraform_workspace_id"
ATTRIBUTE_CONDITION="assertion.sub.startsWith(\"organization:${TFC_ORGANIZATION_NAME}:\")"

if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$IDENTITY_PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$IDENTITY_PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --issuer-uri="https://${TFC_HOSTNAME}" \
    --attribute-mapping="$ATTRIBUTE_MAPPING" \
    --attribute-condition="$ATTRIBUTE_CONDITION" \
    --display-name="Terraform Cloud provider"
else
  # Correct any earlier provider created with placeholder or outdated mappings.
  gcloud iam workload-identity-pools providers update-oidc "$PROVIDER_ID" \
    --project="$IDENTITY_PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --issuer-uri="https://${TFC_HOSTNAME}" \
    --attribute-mapping="$ATTRIBUTE_MAPPING" \
    --attribute-condition="$ATTRIBUTE_CONDITION" \
    --display-name="Terraform Cloud provider"
fi

for role in \
  roles/serviceusage.serviceUsageAdmin \
  roles/compute.networkAdmin \
  roles/artifactregistry.admin \
  roles/storage.admin; do
  gcloud projects add-iam-policy-binding "$TARGET_PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="$role" \
    --condition=None \
    --quiet
done

gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
  --project="$IDENTITY_PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principal://iam.googleapis.com/projects/${IDENTITY_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/${TFC_WORKSPACE_ID}" \
  --condition=None \
  --quiet

echo "Updating Terraform Cloud workspace variables..."
# Remove earlier manual values that can override the separate provider components below.
delete_workspace_variable_if_present "TFC_GCP_WORKLOAD_PROVIDER_NAME"
delete_workspace_variable_if_present "TFC_GCP_WORKLOAD_IDENTITY_AUDIENCE"

# This workspace intentionally passes config/dev.tfvars to every remote plan.
# Keep that file aligned with the new project before changing the workspace.
TARGET_PROJECT_ID="$TARGET_PROJECT_ID" perl -0pi -e \
  's/^project_id\s*=.*$/q{project_id = "} . $ENV{TARGET_PROJECT_ID} . q{"}/me' \
  "$DEV_TFVARS_FILE"

upsert_tfc_variable "project_id" "$TARGET_PROJECT_ID" "terraform" "GCP project managed by this workspace"
upsert_tfc_variable "gcp_region" "$REGION" "terraform" "Default GCP region"
upsert_tfc_variable "env" "$ENVIRONMENT" "terraform" "Terraform environment"
upsert_tfc_variable "TF_CLI_ARGS_plan" "-var-file=config/dev.tfvars" "env" "Load the committed development configuration"
upsert_tfc_variable "TFC_GCP_PROVIDER_AUTH" "true" "env" "Enable HCP Terraform GCP dynamic credentials"
upsert_tfc_variable "TFC_GCP_PRINCIPAL_TYPE" "service_account" "env" "Use service-account impersonation"
upsert_tfc_variable "TFC_GCP_PROJECT_NUMBER" "$IDENTITY_PROJECT_NUMBER" "env" "Project number hosting the workload identity pool"
upsert_tfc_variable "TFC_GCP_WORKLOAD_POOL_ID" "$POOL_ID" "env" "GCP workload identity pool ID"
upsert_tfc_variable "TFC_GCP_WORKLOAD_PROVIDER_ID" "$PROVIDER_ID" "env" "GCP workload identity provider ID"
upsert_tfc_variable "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" "$SERVICE_ACCOUNT_EMAIL" "env" "Service account impersonated by Terraform Cloud"

echo
echo "Bootstrap complete for target project: ${TARGET_PROJECT_ID}"
echo "Updated ${DEV_TFVARS_FILE}; commit and push that project-ID change before a VCS-triggered run."
echo "Terraform Cloud workspace variables are updated. Start a new plan in Terraform Cloud."
