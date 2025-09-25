# Application Monitoring with Prometheus (FastAPI example)

This folder is a tiny, end-to-end setup that shows how to monitor an application on Kubernetes using:

- A sample FastAPI app that exposes Prometheus metrics
- A Kubernetes Service to expose the app
- A ServiceMonitor so Prometheus Operator discovers and scrapes the app
- A Grafana dashboard (as a ConfigMap) that visualizes key app metrics

It’s intentionally small and opinionated so you can copy it as a starter and adapt it to your cluster.

## What’s inside

- `deployment.yaml` — Deploys `fastapi-app` (image: `emergingtechnologies2016/fastapi-prometheus:latest`) in namespace `monitoring`, listening on container port `8000` (named `web`).
- `service.yaml` — ClusterIP Service `fastapi-app` on port `8000` (name `web`), selects pods with `app: fastapi-app`.
- `servicemonitor.yaml` — Prometheus Operator CRD. Scrapes the Service on `port: web`, `path: /metrics`, every `15s`. Labeled with `release: prometheus` so it matches a Helm release named `prometheus` of the kube-prometheus-stack.
- `configmap.yaml` — A Grafana dashboard (`metadata.name: fastapi-dashboard`) labeled `grafana_dashboard: "1"`. It charts:
  - Request rate: `rate(http_request_total[1m])`
  - Avg response time: `rate(http_request_duration_seconds_sum[1m]) / rate(http_request_duration_seconds_count[1m])`
  - Process memory: `process_resident_memory_bytes`
  - CPU usage: `process_cpu_usage`

Grafana dashboard title: “FastAPI Python Application Dashboard”, UID: `python_fastapi_dashboard`.

## Prerequisites

- A running Kubernetes cluster (local or cloud)
- kubectl and Helm on your machine
- Namespace `monitoring`
- Prometheus Operator + Grafana (easiest via Helm chart `kube-prometheus-stack`)

If you’re not sure Prometheus Operator CRDs are installed, check:

```bash
kubectl api-resources | grep servicemonitors
```

If you get no result, install the stack as shown below.

## Install Prometheus + Grafana (kube-prometheus-stack)

If you don’t already have Prometheus Operator/Grafana in `monitoring`, install them with Helm. The ServiceMonitor in this folder assumes the Helm release name is `prometheus` in namespace `monitoring` (that’s why the label `release: prometheus` exists in `servicemonitor.yaml`).

```bash
# Create namespace (safe to re-run)
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Add the repo (once) and update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack with release name "prometheus" in namespace "monitoring"
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

Notes:

- If you already have the stack installed under a different release name (e.g., `obs`), either:
  - change `release: prometheus` in `servicemonitor.yaml` to match your release label, or
  - reinstall the chart with release name `prometheus`.
- The chart includes Grafana. The ConfigMap in this folder uses the standard label `grafana_dashboard: "1"` that the Grafana sidecar watches by default.

## Deploy the sample app + monitoring bits

Apply the manifests in this folder. They all target the `monitoring` namespace.

```bash
kubectl apply -n monitoring -f deployment.yaml
kubectl apply -n monitoring -f service.yaml
kubectl apply -n monitoring -f servicemonitor.yaml
kubectl apply -n monitoring -f configmap.yaml
```

Verify the app and Service are up:

```bash
kubectl get pods -n monitoring -l app=fastapi-app
kubectl get svc  -n monitoring fastapi-app
```

Optionally port-forward the Service to hit the app and metrics locally:

```bash
kubectl -n monitoring port-forward svc/fastapi-app 8000:8000
# In another terminal
curl -s http://localhost:8000/        # app endpoint (example)
curl -s http://localhost:8000/metrics # Prometheus metrics
```

## Check Prometheus scraping

Port-forward Prometheus and confirm the target is discovered via the ServiceMonitor.

```bash
# Service name may vary slightly with chart version. If the command errors, list services first.
kubectl -n monitoring get svc | grep prometheus

# Common name:
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090

# Then open: http://localhost:9090/targets
# You should see a target for the fastapi-app (path /metrics) up and healthy.
```

Queries to try in Prometheus UI:

- `rate(http_request_total[1m])`
- `rate(http_request_duration_seconds_sum[1m]) / rate(http_request_duration_seconds_count[1m])`
- `process_resident_memory_bytes`
- `process_cpu_usage`

Generate a bit of traffic to make the graphs interesting (new terminal while port-forwarding the app):

```bash
for i in {1..100}; do curl -s http://localhost:8000 >/dev/null; done
```

## View the Grafana dashboard

Port-forward Grafana and log in. The chart creates a random admin password; fetch it from the Secret.

```bash
# Port-forward Grafana (name is stable when release is `prometheus`)
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80

# Get admin password
kubectl -n monitoring get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo

# Open Grafana: http://localhost:3000
# Username: admin
# Password: (value printed above)
```

Once in Grafana, search for “FastAPI Python Application Dashboard” (UID `python_fastapi_dashboard`). If you don’t see it:

- Ensure the ConfigMap `fastapi-dashboard` is in namespace `monitoring` and has label `grafana_dashboard: "1"`.
- Confirm the Grafana sidecar for dashboards is enabled in the Helm values (it is enabled by default in kube-prometheus-stack).

## Customization

- Different namespace: update `metadata.namespace` in all files or deploy into your desired namespace with `-n <ns>` and remove the hardcoded `namespace:` fields.
- Different release name for kube-prometheus-stack: change `metadata.labels.release` in `servicemonitor.yaml` to match your release.
- App image/port: change the image or the `containerPort`/Service port and keep the `endpoints.port` in the ServiceMonitor in sync.
- Dashboard tweaks: edit queries in `configmap.yaml` under `fastapi-dashboard.json`. You can also export/import from Grafana and paste here.

## Troubleshooting

- `helm delete prometheus` fails: add `-n monitoring` (release is namespaced). Example: `helm delete prometheus -n monitoring`.
- ServiceMonitor not picked up:
  - Check CRD is installed: `kubectl api-resources | grep servicemonitors`.
  - The label `release: prometheus` must match your Helm release label for kube-prometheus-stack.
  - Prometheus logs (under the Prometheus pod) will show discovery issues.
- Grafana dashboard not appearing:
  - Verify ConfigMap label `grafana_dashboard: "1"` and namespace matches Grafana’s namespace.
  - Check Grafana sidecar logs (container in the Grafana pod) for dashboard import errors.
- No metrics / empty graphs:
  - Hit the app endpoint a few times to generate traffic.
  - Confirm `/metrics` returns data.
  - Ensure Service port name (`web`) matches the ServiceMonitor endpoint `port`.

## Cleanup

```bash
# Remove app + Service + ServiceMonitor + dashboard
kubectl delete -n monitoring -f configmap.yaml || true
kubectl delete -n monitoring -f servicemonitor.yaml || true
kubectl delete -n monitoring -f service.yaml || true
kubectl delete -n monitoring -f deployment.yaml || true

# Optional: remove kube-prometheus-stack (be careful if shared!)
helm uninstall prometheus -n monitoring || true
```

## Why this pattern

- ServiceMonitor keeps Prometheus scrape config declarative and lives with your app.
- Named Service ports and consistent labels make discovery reliable.
- Dashboards-as-code (ConfigMap) make Grafana portable and reviewable.

Use this as a minimal, working template; swap in your own app, refine the dashboard, and keep everything in Git.
