# Distributed Tracing with Tempo, Alloy and Grafana on Kubernetes

This repository demonstrates how to set up a complete distributed tracing solution on Kubernetes using Grafana's observability stack. The setup includes Prometheus for metrics, Tempo for trace storage, Alloy for trace processing, and a sample trace generator.

## Stack Components

- **Prometheus + Grafana**: Metrics collection and visualization (kube-prometheus-stack)
- **Tempo**: Distributed tracing backend
- **Alloy**: Trace data processor and transformer
- **K6 Trace Generator**: Sample app generating OpenTelemetry traces

## Prerequisites

- Kubernetes cluster (local or cloud)
- Helm 3.x
- kubectl configured to access your cluster
- At least 4GB available memory for the stack

## Quick Start

1. **Create the monitoring namespace**
```bash
kubectl create namespace monitoring
```

2. **Add required Helm repositories**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

3. **Deploy Prometheus + Grafana stack**
```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --version 72.6.2 \
  --namespace monitoring \
  --values helm/prometheus-stack-values.yaml \
  --wait
```

4. **Deploy Tempo**
```bash
helm install tempo grafana/tempo \
  --version 1.21.1 \
  --namespace monitoring \
  --values helm/tempo-values.yaml \
  --wait
```

5. **Deploy Alloy**
```bash
helm install alloy grafana/alloy \
  --version 1.0.3 \
  --namespace monitoring \
  --values helm/alloy-values.yaml \
  --wait
```

6. **Deploy the trace generator**
```bash
kubectl apply -f trace-generator.yaml
```

## Accessing the UI

1. **Port-forward Grafana**
```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

2. **Access Grafana**
- Open http://127.0.0.1:3000 in your browser
- Default credentials:
  - Username: admin
  - Password: auto-generated (retrieve if needed with):
    ```bash
    kubectl -n monitoring get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
    ```

## Exploring Traces

1. **View Generated Traces**
- In Grafana, click "Explore"
- Select "Tempo" as the data source
- Choose "Search" as the query type
- You'll see incoming traces from the generator

2. **Analyze Traces**
- Click on any Trace ID to see the detailed trace view
- Use the Service Graph view for dependency visualization
- Access the pre-built traces dashboard at:
  http://127.0.0.1:3000/a/grafana-exploretracesapp

## Validation

Check if all components are running:
```bash
kubectl get pods -n monitoring
```

View trace generator logs:
```bash
kubectl logs -f -l app=k6-trace-generator -n monitoring
```

## Cleanup

Remove everything with:
```bash
# Uninstall Helm releases
helm uninstall tempo -n monitoring
helm uninstall alloy -n monitoring
helm uninstall monitoring -n monitoring

# Remove all resources
kubectl delete all --all -n monitoring

# Clean up CRDs
kubectl get crds | grep 'prometheus\|monitoring\|tempo\|alloy' | xargs kubectl delete crd

# Delete namespace
kubectl delete namespace monitoring
```

## Configuration

The setup uses custom values files for each component:

- `helm/prometheus-stack-values.yaml`: Prometheus + Grafana configuration
- `helm/tempo-values.yaml`: Tempo settings
- `helm/alloy-values.yaml`: Alloy processor configuration
- `trace-generator.yaml`: Sample trace generator deployment

## Troubleshooting

1. **No traces appearing?**
   - Check trace generator is running: `kubectl logs -f -l app=k6-trace-generator -n monitoring`
   - Verify Tempo is receiving data: Check Tempo logs
   - Ensure proper network connectivity between components

2. **Grafana can't connect to Tempo?**
   - Verify the Tempo data source is configured correctly
   - Check if Tempo service is running: `kubectl get svc -n monitoring`

3. **High memory usage?**
   - Adjust resource limits in the respective values files
   - Consider enabling persistence for longer retention

## Additional Resources

- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana Tracing Guide](https://grafana.com/docs/grafana/latest/explore/trace-integration/)
- [OpenTelemetry Integration](https://opentelemetry.io/docs/instrumentation/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.