#!/usr/bin/env bash
# GCP Full Resource Audit using gcloud CLI
# Fast, dependency-free, and clean output

set -euo pipefail

PROJECT_ID="${GCP_PROJECT:-}"
if [[ -z "$PROJECT_ID" ]]; then
  read -rp "Enter your GCP Project ID: " PROJECT_ID
fi
gcloud config set project "$PROJECT_ID" >/dev/null

echo "=============================================="
echo "  GCP RESOURCE AUDIT for Project: $PROJECT_ID"
echo "=============================================="

# 1. Cloud Asset Inventory
echo ""
echo "=== Cloud Asset Inventory ==="
assets=$(gcloud asset list --project="$PROJECT_ID" --content-type=resource \
  --format="value(assetType,name)" | grep -v -E "storage.googleapis.com/Bucket|iam.googleapis.com/ServiceAccount" || true)
if [[ -z "$assets" ]]; then
  echo "No Resources found here."
else
  echo "$assets"
fi

# 2. Compute Engine VMs
echo ""
echo "=== Compute Engine Instances ==="
compute=$(gcloud compute instances list --project="$PROJECT_ID" --format="table(name,zone,status)" || true)
if [[ -z "$compute" || "$compute" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$compute"
fi

# 3. GKE Clusters
echo ""
echo "=== GKE Clusters ==="
gke=$(gcloud container clusters list --project="$PROJECT_ID" --format="table(name,location,status)" || true)
if [[ -z "$gke" || "$gke" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$gke"
fi

# 4. Dataflow Jobs
echo ""
echo "=== Dataflow Jobs ==="
dataflow=$(gcloud dataflow jobs list --project="$PROJECT_ID" --region=us-central1 \
  --format="table(name,state,creationTime)" || true)
if [[ -z "$dataflow" || "$dataflow" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$dataflow"
fi

# 5. Cloud SQL Instances
echo ""
echo "=== Cloud SQL Instances ==="
sql=$(gcloud sql instances list --project="$PROJECT_ID" --format="table(name,region,state)" || true)
if [[ -z "$sql" || "$sql" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$sql"
fi

# 6. Pub/Sub
echo ""
echo "=== Pub/Sub Topics ==="
topics=$(gcloud pubsub topics list --project="$PROJECT_ID" --format="value(name)" || true)
if [[ -z "$topics" ]]; then
  echo "No Resources found here."
else
  echo "$topics"
fi

echo ""
echo "=== Pub/Sub Subscriptions ==="
subs=$(gcloud pubsub subscriptions list --project="$PROJECT_ID" --format="value(name)" || true)
if [[ -z "$subs" ]]; then
  echo "No Resources found here."
else
  echo "$subs"
fi

# 7. BigQuery
echo ""
echo "=== BigQuery Datasets & Tables ==="
datasets=$(bq --project_id="$PROJECT_ID" ls --format=json 2>/dev/null | jq -r '.[].datasetReference.datasetId' || true)
if [[ -z "$datasets" ]]; then
  echo "No Resources found here."
else
  for dataset in $datasets; do
    echo "Dataset: $dataset"
    tables=$(bq --project_id="$PROJECT_ID" ls "$dataset" --format="table(tableId,type)" 2>/dev/null || true)
    if [[ -z "$tables" ]]; then
      echo "  No Tables found here."
    else
      echo "$tables"
    fi
  done
fi

# 8. Vertex AI
echo ""
echo "=== Vertex AI Models ==="
models=$(gcloud ai models list --project="$PROJECT_ID" --region=us-central1 \
  --format="table(displayName,createTime)" || true)
if [[ -z "$models" || "$models" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$models"
fi

echo ""
echo "=== Vertex AI Endpoints ==="
endpoints=$(gcloud ai endpoints list --project="$PROJECT_ID" --region=us-central1 \
  --format="table(displayName,createTime)" || true)
if [[ -z "$endpoints" || "$endpoints" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$endpoints"
fi

# 9. Secret Manager
echo ""
echo "=== Secret Manager ==="
secrets=$(gcloud secrets list --project="$PROJECT_ID" --format="table(name,replication)" || true)
if [[ -z "$secrets" || "$secrets" == "Listed 0 items." ]]; then
  echo "No Resources found here."
else
  echo "$secrets"
fi

echo ""
echo "✅ Audit complete — review all sections above."
echo "=============================================="
