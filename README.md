# Modern Engineering Alchemy

A comprehensive collection of modern DevOps, Platform Engineering, and Cloud-Native practices with hands-on examples and real-world implementations.

## Repository Overview

This repository serves as a complete learning and reference guide for modern engineering practices, covering everything from basic Kubernetes concepts to advanced platform engineering patterns.

## Directory Structure & Purpose

### 🔍 cloud-resource-audit/
**Purpose**: Cloud resource auditing and compliance tools
- **gcp-resource-checking/**: Complete GCP resource audit automation
  - `gcp_full_audit.py`: Python script for comprehensive GCP resource scanning
  - `gcp_full_audit.sh`: Shell script wrapper for audit execution
- **Benefits**: Cost optimization, security compliance, resource governance

### 📊 full-stack-observability/
**Purpose**: Complete observability stack implementations for modern applications

#### application-monitroing-prometheus/
- Prometheus-based application monitoring setup
- **Includes**: ConfigMap, Deployment, Service, ServiceMonitor configurations
- **Benefits**: Real-time metrics collection and alerting

#### loki-k8s-app-observability/
- Log aggregation and analysis with Grafana Loki
- **Features**: Centralized logging, log correlation with metrics
- **Components**: Loki values, Prometheus integration, Grafana dashboards

#### tempo-alloy-grafana-distributed-tracing-kubernetes/
- Distributed tracing implementation using Grafana Tempo and Alloy
- **Benefits**: End-to-end request tracing, performance bottleneck identification
- **Includes**: Helm charts, trace generators, complete observability stack

### platform-cicd-blueprints/
**Purpose**: Production-ready CI/CD pipeline templates and blueprints

#### cicd-gh-actions/
- **ep2-aws/**: AWS-focused GitHub Actions workflows
  - S3 deployment pipelines
  - Static website hosting automation
  - Infrastructure as Code integration
- **tf-actions/**: Terraform automation with GitHub Actions
  - Automated infrastructure provisioning
  - State management and backend configuration

### 🏗️ platform-engineering-playbook/
**Purpose**: Complete platform engineering patterns and best practices

#### cloud-native-python-app/
- Full-stack cloud-native application example
- **Features**: 
  - Docker containerization
  - Kubernetes deployment manifests
  - Helm charts for package management
  - ArgoCD GitOps integration
  - GitHub Actions CI/CD pipeline
- **Benefits**: Production-ready application template

#### gitops-multi-deployment-patterns/
- Multiple GitOps deployment strategies
- **Patterns**: Basic GitOps, Helm-based, Kustomize-based deployments
- **Tools**: ArgoCD applications and configurations
- **Benefits**: Declarative deployment management, environment consistency

### 🧪 practice-labs/
**Purpose**: Hands-on learning laboratories for Kubernetes and DevOps concepts

#### deployments/
- Various Kubernetes deployment strategies
- **Examples**: Rolling updates, recreate deployments, nginx configurations
- **Benefits**: Understanding deployment patterns and strategies

#### platform-devops-dojo/
Comprehensive learning path for DevOps engineers

##### k8s-coaching/ (11 Progressive Modules)
1. **01-pods-containers/**: Container fundamentals
2. **02-service-discovry/**: Service networking and discovery
3. **03-namespace/**: Multi-tenancy and resource isolation
4. **04-deployments-replicas/**: Application deployment patterns
5. **05-rolling-updates-rollbacks/**: Zero-downtime deployments
6. **06-liveness-readiness-probes/**: Health checking and monitoring
7. **07-statefulset-persistent-volume/**: Stateful application management
8. **08-configmap-secret/**: Configuration and secrets management
9. **09-horizontal-pod-autoscaler/**: Auto-scaling implementations
10. **10-ingress-controller/**: Traffic routing and SSL termination
11. **11-helm-charts/**: Package management and templating
12. **12-upgrading-helm-charts/**: Chart lifecycle management
13. **13-k8s-operators/**: Custom resource management

##### terraform-session/
- **conditional-statements/**: Logic and control flow in Terraform
- **datasources/**: External data integration
- **lifecycle-rules/**: Resource lifecycle management
- **terraform-dojo/**: Practical Terraform exercises
- **usecases/**: Real-world implementation scenarios

### 🔐 devsecops-workflows/
**Purpose**: Security-integrated development workflows
- Security scanning integration
- Compliance automation
- Vulnerability management

## 🌟 Key Features & Benefits

### For Beginners
- **Progressive Learning Path**: Start with basic concepts and advance to complex implementations
- **Hands-on Labs**: Practical exercises with real-world scenarios
- **Complete Examples**: Working code that can be deployed immediately

### For Intermediate Engineers
- **Best Practices**: Industry-standard implementations and patterns
- **Multi-Tool Integration**: Learn how different tools work together
- **Real-world Scenarios**: Production-ready configurations and setups

### For Advanced Practitioners
- **Platform Engineering Patterns**: Complete platform building blocks
- **Observability Stack**: Full monitoring, logging, and tracing solutions
- **GitOps Workflows**: Advanced deployment and management strategies

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd modern-engineering-alchemy
   ```

2. **Choose your learning path**
   - Start with `practice-labs/platform-devops-dojo/k8s-coaching/` for Kubernetes basics
   - Explore `full-stack-observability/` for monitoring and observability
   - Check `platform-engineering-playbook/` for complete application examples

3. **Follow the README files** in each directory for specific setup instructions

## Prerequisites

- Docker and Kubernetes cluster access
- Basic understanding of containers and orchestration
- Git and command-line familiarity
- Cloud provider account (for cloud-specific examples)

## 📚 Learning Objectives

After working through this repository, you will understand:
- Modern DevOps and Platform Engineering practices
- Complete observability stack implementation
- GitOps workflows and deployment strategies
- Infrastructure as Code with Terraform
- Kubernetes from basics to advanced patterns
- CI/CD pipeline design and implementation
- Security integration in development workflows

## 🤝 Contributing

This repository is designed to be a living collection of modern engineering practices. Contributions, improvements, and additional examples are welcome.

## 📄 License

Please refer to individual directories for specific licensing information.