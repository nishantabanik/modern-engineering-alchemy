# GCP Terraform Cloud bootstrap

`bootstrap-tfc-gcp.sh` prepares an existing GCP project for the `modern-engineering-alchemy` Terraform Cloud workspace.

It uses the signed-in human GCP administrator only to create the initial trust. It then creates a dedicated service account, a Workload Identity Pool and provider restricted to the Terraform Cloud organization and workspace, required bootstrap APIs, and workspace variables through the Terraform Cloud API. It does not create a service-account key and it does not run `terraform apply`.

The provider validates the Terraform Cloud organization from the signed OIDC subject. The service account's `roles/iam.workloadIdentityUser` binding then restricts impersonation to the exact Terraform Cloud workspace ID. Both checks are required.

The script also replaces `project_id` in `enterprise-tfe-orchestrator/platform-foundation/config/dev.tfvars`, because this workspace deliberately passes that file with `TF_CLI_ARGS_plan`. Commit and push that resulting change before a VCS-triggered run.

Best long-term pattern: keep a small permanent **identity project** that contains the Workload Identity Pool and Terraform Cloud service account. Create and delete playground projects freely. The script grants that permanent service account access to each new target project and updates the workspace target `project_id` variable.

Before each new playground project, authenticate as a GCP administrator and set a Terraform Cloud API token only in your current terminal session. `GCP_IDENTITY_PROJECT_ID` means the permanent GCP project that hosts the identity resources; it is not a value from Terraform Cloud:

```bash
gcloud auth login
export TFC_TOKEN="paste-your-Terraform-Cloud-token-here"
GCP_IDENTITY_PROJECT_ID="your-permanent-identity-project-id" \
  ./scripts/bootstrap-tfc-gcp.sh "your-new-gcp-project-id"
```

If you do not yet have a permanent identity project, omit `GCP_IDENTITY_PROJECT_ID`. The script then creates the identity resources in the target project; this is simpler but they will be deleted with that project.

The token needs permission to read and write variables in workspace `ws-HbPUo3znoyosCBgv`. Never commit or paste the token into source code, Terraform variables, GitHub Actions secrets, or chat.

The script prepares an **existing** GCP project. Project creation is intentionally separate because it requires a billing account and, in many organizations, an explicit folder or parent choice. If you delete a project outside Terraform, use a new Terraform Cloud workspace or explicitly clear the old workspace state before reusing it; otherwise the old state can make the next plan misleading.

If the Terraform Cloud workspace is recreated, set its new ID for that run:

```bash
TFC_WORKSPACE_ID="ws-replacement" ./scripts/bootstrap-tfc-gcp.sh "your-new-gcp-project-id"
```

The script intentionally uses service-account impersonation. HCP Terraform requires this model; direct resource access by a federated principal is not supported for HCP Terraform.
