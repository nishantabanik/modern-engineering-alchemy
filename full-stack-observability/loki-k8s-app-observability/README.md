# Loki + Prometheus + Grafana: Kubernetes App Observability

This folder is a small but complete setup to get application logs and metrics flowing in Kubernetes using Loki (logs), Prometheus (metrics), and Grafana (dashboards). There’s also a tiny test workload that emits fake logs/metrics so you can see everything working end-to-end.

## What’s here

- `loki/loki-values.yaml`: Helm values for deploying Loki (and usually promtail) on Kubernetes.
- `prometheus/prometheus-values.yaml`: Helm values for deploying Prometheus (typically via kube-prometheus-stack, which also includes Grafana and exporters).
- `grafana/grafana-dashboard.json`: A sample Grafana dashboard you can import.
- `test/fake-metrics-logs.yaml`: A simple test workload that generates logs and metrics (labelled so they’re easy to query, e.g., `job="test"`).

Use this as a starting point and swap in your own applications later.

## Prerequisites

- A running Kubernetes cluster (kind/minikube/managed)
- kubectl and Helm installed
- A namespace (examples below use `monitoring`)

Create the namespace (safe to re-run):

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
```

## Install charts

Add Helm repos once and update:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Install Loki (+ promtail). Two common options depending on which chart you prefer:

Option A: loki-stack (includes promtail; great for quick starts):

```bash
helm install loki grafana/loki-stack \
  -n monitoring \
  -f loki/loki-values.yaml
```

Option B: Loki distributed (install promtail separately):

```bash
helm install loki grafana/loki \
  -n monitoring \
  -f loki/loki-values.yaml

# If using this option, also install promtail:
# helm install promtail grafana/promtail -n monitoring -f loki/loki-values.yaml
```

Install Prometheus (with Grafana): easiest via kube-prometheus-stack:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus/prometheus-values.yaml
```

Notes:

- Release names above are `loki` and `prometheus` in namespace `monitoring`. Adjust if you use different names.
- If your `prometheus-values.yaml` already configures a Grafana Loki datasource, you won’t need to add it manually. Otherwise, you can add the Loki datasource in Grafana UI (Settings → Data sources → Add data source → Loki). The Loki URL is typically `http://loki:3100` within the cluster.

## Deploy the test workload

```bash
kubectl apply -n monitoring -f test/fake-metrics-logs.yaml
```

Give it a minute to start producing logs and metrics.

## Verify metrics in Prometheus

Port-forward Prometheus and open the UI:

```bash
# Service name can vary across chart versions. If this errors, list services first:
# kubectl -n monitoring get svc | grep prometheus

kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Open <http://localhost:9090> and try a few queries (examples):

- `up` (sanity check that targets are being scraped)
- `sum by (job) (rate(http_requests_total[1m]))`
- `sum by (pod) (container_cpu_usage_seconds_total)`

Tip: If the test workload uses the label `job="test"`, you can filter queries with `{job="test"}` and browse the graph/console.

## Verify logs in Loki

Port-forward Loki (service name may vary: try `loki`, `loki-headless`, or `loki-gateway`):

```bash
kubectl -n monitoring get svc | grep loki
kubectl -n monitoring port-forward svc/loki 3100:3100
```

Query Loki’s API from your terminal (LogQL):

```bash
curl "http://127.0.0.1:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="test"}' | jq .data.result
```

If you see log streams returned, promtail → Loki ingestion is working.

## Grafana: visualize both

Port-forward Grafana (created by kube-prometheus-stack):

```bash
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80
```

Get the admin password:

```bash
kubectl -n monitoring get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

Open <http://localhost:3000> (user: `admin`, password: printed above).

### Add Loki as a datasource (if not already present)

- In Grafana, go to Settings → Data sources → Add data source
- Choose Loki, set URL to `http://loki:3100` (or whatever matches your Service), Save & Test

### Import the sample dashboard

- In Grafana, Dashboards → Import → Upload JSON → select `grafana/grafana-dashboard.json`
- Pick your Prometheus and Loki data sources when prompted
- Save and open the dashboard

## Useful queries

Prometheus (metrics):

- Requests per second: `sum(rate(http_requests_total[1m]))`
- CPU by pod: `sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))`
- Memory by pod: `sum by (pod) (container_memory_working_set_bytes)`

Loki (logs):

- All logs from the test job: `{job="test"}`
- Errors only: `{job="test"} |= "error"`
- Tail live in Grafana Explore: switch to Loki, run `{job="test"}` and click Live tail

## Troubleshooting

- No `ServiceMonitor` CRD? kube-prometheus-stack installs Prometheus Operator and CRDs. Verify with:

```bash
kubectl api-resources | grep servicemonitors
```

- No logs in Loki:

  - Ensure promtail is installed and scraping your pods/nodes.
  - Check promtail targets and logs.
  - Confirm Loki service is reachable (`kubectl -n monitoring get svc | grep loki`).

- Grafana can’t see Loki:

  - Add a Loki datasource pointing to the correct in-cluster URL.
  - If using NetworkPolicies, allow Grafana → Loki traffic.

- Prometheus missing metrics:

  - Verify the test pod exposes `/metrics` and is scraped (Targets page in Prometheus UI).
  - Inspect labels; filter by `{job="test"}` to narrow down.

- Service names differ from examples:
  - List services with `kubectl -n monitoring get svc` and adjust the port-forward command accordingly.

## Customize

- Change namespaces: edit `-n monitoring` flags and/or set `namespace:` in your values/manifests.
- Storage and retention: tune Loki, Prometheus, and Grafana persistence and retention in the values files.
- Dashboards-as-code: turn `grafana-dashboard.json` into a Kubernetes ConfigMap and enable Grafana’s dashboard sidecar for automatic import.
- Multi-tenant or production Loki: prefer the `loki`/`loki-distributed` charts with proper persistence and compactor settings.

## Cleanup

```bash
# Remove the test workload
kubectl delete -n monitoring -f test/fake-metrics-logs.yaml || true

# Remove the stacks (only if you’re done and they’re not shared!)
helm uninstall loki -n monitoring || true
helm uninstall prometheus -n monitoring || true
```

## Why this setup

- Prometheus + Grafana: de facto standard for application and cluster metrics
- Loki + promtail: simple, scalable logs with a familiar Grafana experience
- Everything is configurable via Helm values so you can grow from local demos to production
