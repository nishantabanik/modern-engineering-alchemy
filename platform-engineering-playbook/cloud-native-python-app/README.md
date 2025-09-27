# Cloud-Native Python App: From Local Dev to GitOps CI/CD on Kubernetes

This repo walks a small Flask app from local development to containerization, Kubernetes deployment, Helm packaging, Argo CD GitOps, and GitHub Actions CI/CD with self‑hosted runners. It also covers local ingress on kind with custom hostnames.

It’s opinionated and practical: you can copy/paste steps and adapt to your environment. Secrets shown below must be set as GitHub repo secrets; never hardcode tokens.

---

## Repo Structure

- `src/app.py`: Flask app exposing two endpoints:
  - `GET /api/v1/info`
  - `GET /api/v1/healthz`
- `requirements.txt`: Python dependencies (Flask)
- `Dockerfile`: Minimal Python 3.10 Alpine image
- `k8s/`: Raw K8s manifests for app Deploy/Service/Ingress
  - `deploy.yaml`: Deployment using Docker Hub image
  - `service.yaml`: ClusterIP Service mapping 8080 → 5000
  - `ingress.yaml`: Ingress for host `python-app.test.com`
- `charts/python-app/`: Helm chart for the app
  - `values.yaml`: image.repo/tag, service.port, ingress host, probes, resources
  - `templates/`: Deployment/Service/Ingress templates (ports/probes wired to values)
- `charts/argocd/values-argo.yaml`: Values for Argo CD chart (domain, ingress, annotations)
- `.github/workflows/cicd.yaml`: CI builds/pushes image; CD updates Helm values and Argo CD syncs

---

## 1) Local development

```bash
python3 --version
pip3 install -r requirements.txt
python3 src/app.py
```

Then hit locally:

```bash
curl -s http://127.0.0.1:5000/api/v1/healthz
curl -s http://127.0.0.1:5000/api/v1/info
```

Notes

- The app binds to `0.0.0.0` in `src/app.py`. If you ever can’t reach it from outside a container, ensure `host="0.0.0.0"` is set when calling `app.run(...)`.

---

## 2) Container build and push

`Dockerfile`:

```dockerfile
FROM python:3.10-alpine
COPY requirements.txt /tmp
RUN pip install -r /tmp/requirements.txt
COPY ./src /src
CMD python /src/app.py
```

Build, run locally, and test:

```bash
docker build -t python-app:v1 .
docker run --rm -p 8080:5000 python-app:v1
# If you can’t reach http://127.0.0.1:8080/ then ensure app binds 0.0.0.0
curl -s http://127.0.0.1:8080/api/v1/healthz
curl -s http://127.0.0.1:8080/api/v1/info
```

Tag and push to Docker Hub (use your repo):

```bash
docker login -u <DOCKERHUB_USERNAME>  # will prompt for token/password
docker tag python-app:v1 <DOCKERHUB_USERNAME>/python-app:v1
docker push <DOCKERHUB_USERNAME>/python-app:v1
```

Housekeeping:

```bash
docker images -f "dangling=true"
docker image prune -f
```

Security

- Use a Docker Hub Personal Access Token; never commit it. Store as a GitHub Action secret instead.

---

## 3) kind cluster with NGINX ingress and hostnames

Create a kind cluster that maps host ports 80/443 to the control-plane node:

```bash
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

Install NGINX Ingress for kind:

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl get all -n ingress-nginx
```

Add local DNS for the app hostname:

- Edit `/etc/hosts` and add: `127.0.0.1 python-app.test.com`

---

## 4) Deploy with raw Kubernetes manifests

`k8s/deploy.yaml` (image points to Docker Hub):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
  labels:
    app: python-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-app
  template:
    metadata:
      labels:
        app: python-app
    spec:
      containers:
        - name: python-app
          image: emergingtechnologies2016/python-app:v2
          ports:
            - containerPort: 5000
```

`k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: python-app
spec:
  selector:
    app: python-app
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 5000
```

`k8s/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: python-app
spec:
  rules:
    - host: 'python-app.test.com'
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: python-app
                port:
                  number: 8080
```

Apply and verify:

```bash
kubectl apply -f k8s/
kubectl get deploy,svc,ing
kubectl describe svc python-app  # Endpoints should show PodIP:5000
```

Browse:

```bash
curl -s http://python-app.test.com/api/v1/healthz
curl -s http://python-app.test.com/api/v1/info
```

---

## 5) Helm chart deployment (recommended)

We scaffolded the chart via `helm create python-app` and trimmed defaults. Key `values.yaml` settings:

```yaml
image:
  repository: emergingtechnologies2016/python-app
  pullPolicy: IfNotPresent
  tag: 71d6ae  # overwritten by CI/CD to short SHA
service:
  type: ClusterIP
  port: 5000
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: python-app.test.com
      paths:
        - path: /
          pathType: Prefix
livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http
readinessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

Install to a namespace (created automatically):

```bash
helm install python-app -n python ./charts/python-app --create-namespace
kubectl get all -n python
```

Upgrade/uninstall:

```bash
helm upgrade python-app -n python ./charts/python-app
helm uninstall python-app -n python
```

---

## 6) Argo CD installation with Ingress

We install Argo CD via Helm using values in `charts/argocd/values-argo.yaml`.

Recommended values to set (examples):

```yaml
global:
  domain: argocd.test.com

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.test.com
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"  # fixes too many redirects
```

Map the hostname locally:

- Edit `/etc/hosts` and add: `127.0.0.1 argocd.test.com`

Install:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f charts/argocd/values-argo.yaml
```

Get the admin password and log in:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
open https://argocd.test.com
```

Create an application pointing to this repo:

- Repository URL: your GitHub repo URL
- Revision: `main`
- Path: `charts/python-app`
- Destination: your cluster/namespace (e.g. `python`)

Argo CD will now watch the Helm chart path for changes.

---

## 7) Self‑hosted GitHub runners in Kubernetes (CD inside cluster)

We deploy actions-runner-controller to run GitHub Actions inside the cluster.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.yaml
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update
helm upgrade --install actions-runner-controller actions-runner-controller/actions-runner-controller \
  --namespace actions-runner-system --create-namespace \
  --set authSecret.create=true \
  --set authSecret.github_token="<GITHUB_PERSONAL_ACCESS_TOKEN>" \
  --wait
```

Create a RunnerDeployment for this repo:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: self-hosted-runners
  namespace: actions-runner-system
spec:
  replicas: 1
  template:
    spec:
      repository: nishantabanik/cloud-native-python-app
```

Apply it:

```bash
kubectl apply -f <file-above>.yaml
kubectl get pods -n actions-runner-system
```

Check GitHub → Settings → Actions → Runners for a new self-hosted runner.

Security

- Use a token with minimal scopes. Consider GitHub App/OIDC based auth for production.

---

## 8) CI/CD pipeline (GitHub Actions)

Workflow: `.github/workflows/cicd.yaml`

Triggers

```yaml
on:
  push:
    paths:
      - src/**
    branches:
      - main
```

CI job builds and pushes an image tagged with a short commit SHA:

- Shorten commit ID and export as `COMMIT_ID`
- Docker login using `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets
- Build and push to `emergingtechnologies2016/python-app:${{ env.COMMIT_ID }}`
- Expose `commit_id` via job outputs

CD job (runs on self-hosted runner in the cluster):

- Checkout repo
- Update chart image tag using yq:

```bash
yq -Yi '.image.tag = "${{needs.ci.outputs.commit_id}}"' charts/python-app/values.yaml
```

- Commit and push the change (requires repo Workflow permissions → Read and write)
- Install `argocd` CLI in the runner pod
- Login to argocd using the in-cluster service DNS and sync the app:

```bash
argocd login argocd-server.argocd \
  --insecure --grpc-web \
  --username ${{ secrets.ARGOCD_USERNAME }} \
  --password ${{ secrets.ARGOCD_PASSWORD }}
argocd app sync python-app
```

Required GitHub repo secrets

- `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- `ARGOCD_USERNAME`, `ARGOCD_PASSWORD`

Also set repo Settings → Actions → General → Workflow permissions → "Read and write permissions".

Why we update `values.yaml`

- Argo CD watches the chart path. When the pipeline updates the image tag in `charts/python-app/values.yaml` and pushes it, Argo CD detects drift and applies the new image tag to the cluster.

---

## 9) End-to-end test

- Make a small change in `src/app.py` (e.g., the `/api/v1/info` message)
- Commit to `main` and push
- CI builds and pushes a new image tagged with the short SHA
- CD updates `charts/python-app/values.yaml` with that tag and commits back
- Argo CD syncs the app automatically or via the pipeline command
- Verify in the browser:

```bash
curl -s http://python-app.test.com/api/v1/healthz | jq .
curl -s http://python-app.test.com/api/v1/info | jq .
```

You should see the updated content and container tag in Argo CD UI under app → details.

---

## 10) Troubleshooting

- App reachable inside container but not outside:
  - Ensure Flask binds `0.0.0.0` (`app.run(host="0.0.0.0")`)
- Ingress on kind not routing:
  - Verify NGINX Ingress is installed and ready in `ingress-nginx`
  - Ensure `/etc/hosts` has `127.0.0.1 python-app.test.com`
  - Confirm IngressClass and rules
- Argo CD shows too many redirects via Ingress:
  - Add `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` to the Argo CD server Ingress annotations
- `argocd` CLI not found or 404 in runner:
  - Install CLI via curl (see pipeline step) and use `argocd-server.argocd` instead of external DNS
- CD updates `values.yaml` but no rollout:
  - Ensure the commit was pushed (check Actions logs)
  - Ensure Argo CD app points to `charts/python-app` and auto-sync or run `argocd app sync`
- Git push from workflow fails:
  - Ensure Workflow permissions → Read and write
  - Ensure `EndBug/add-and-commit@v9` step runs after modifying the file

---

## Appendix: Handy commands

List resources

```bash
kubectl get ns
kubectl get all -n python
kubectl get ing -n python
kubectl describe svc python-app -n python
```

Helm

```bash
helm list -A
helm get values python-app -n python
```

Argo CD CLI

```bash
argocd app list
argocd app get python-app
argocd app sync python-app
```

---

## License

MIT (or your preferred license)
