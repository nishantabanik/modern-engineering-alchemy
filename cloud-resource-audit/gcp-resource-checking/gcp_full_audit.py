#!/usr/bin/env python3
import os, json
from google.cloud import (
    compute_v1, container_v1, pubsub_v1,
    bigquery, storage, aiplatform_v1,
    monitoring_v3, secretmanager_v1, asset_v1
)
#from googleapiclient import discovery
from googleapiclient.discovery import build

from google.cloud import asset_v1

PROJECT_ID = os.getenv("GCP_PROJECT") or input("Project ID: ").strip()
SCOPE = f"projects/{PROJECT_ID}"
ALLOWED = ("storage.googleapis.com/Bucket", "iam.googleapis.com/ServiceAccount")

def cai_assets():
    client = asset_v1.AssetServiceClient()
    print("\n=== Cloud Asset Inventory scan ===")
    for asset in client.list_assets(request={"parent": SCOPE, "content_type": asset_v1.ContentType.RESOURCE}):
        if asset.asset_type not in ALLOWED:
            print(f"⚠️  {asset.asset_type} → {asset.name}")

def compute_vms():
    print("\n=== Compute VMs ===")
    for zone, resp in compute_v1.InstancesClient().aggregated_list(project=PROJECT_ID):
        if resp.instances:
            for i in resp.instances:
                print(f"VM: {i.name} in {i.zone}")

def gke_clusters():
    print("\n=== GKE Clusters ===")
    parent = f"projects/{PROJECT_ID}/locations/-"
    for c in container_v1.ClusterManagerClient().list_clusters(parent=parent).clusters:
        print(c.name)

def dataflow_jobs():
    print("\n=== Dataflow Jobs ===")
    service = build("dataflow", "v1b3")
    request = service.projects().locations().jobs().list(projectId=PROJECT_ID, location="us-central1")
    response = request.execute()

    if "jobs" in response:
        for job in response["jobs"]:
            print(f"Job: {job['name']} | State: {job['currentState']}")
    else:
        print("No Dataflow jobs found.")


def sql_instances():
    print("\n=== Cloud SQL Instances ===")
    service = discovery.build("sqladmin", "v1beta4")
    request = service.instances().list(project=PROJECT_ID)
    response = request.execute()

    if "items" in response:
        for db in response["items"]:
            print(f"SQL Instance: {db['name']} | Region: {db['region']}")
    else:
        print("No Cloud SQL instances found.")


def pubsub():
    print("\n=== Pub/Sub ===")
    pub = pubsub_v1.PublisherClient()
    sub = pubsub_v1.SubscriberClient()
    for t in pub.list_topics(request={"project": f"projects/{PROJECT_ID}"}): print("Topic:", t.name)
    for s in sub.list_subscriptions(request={"project": f"projects/{PROJECT_ID}"}): print("Subscription:", s.name)

def bigquery_resources():
    print("\n=== BigQuery ===")
    bq = bigquery.Client(project=PROJECT_ID)
    for ds in bq.list_datasets():
        for t in bq.list_tables(ds.dataset_id):
            print(f"{ds.dataset_id}.{t.table_id}")

def vertex_ai():
    print("\n=== Vertex AI ===")
    parent = f"projects/{PROJECT_ID}/locations/-"
    for m in aiplatform_v1.ModelServiceClient().list_models(parent=parent):
        print("Model:", m.name)
    for e in aiplatform_v1.EndpointServiceClient().list_endpoints(parent=parent):
        print("Endpoint:", e.name)

def secrets():
    print("\n=== Secret Manager ===")
    parent = f"projects/{PROJECT_ID}"
    for s in secretmanager_v1.SecretManagerServiceClient().list_secrets(request={"parent": parent}):
        print(s.name)

def main():
    cai_assets()
    compute_vms()
    gke_clusters()
    dataflow_jobs()
    sql_instances()
    pubsub()
    bigquery_resources()
    vertex_ai()
    secrets()
    print("\n✅ Audit complete — review anything printed above.")

if __name__ == "__main__":
    main()