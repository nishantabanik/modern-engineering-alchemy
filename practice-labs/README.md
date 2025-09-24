# Practice Labs

This repository contains a collection of hands-on labs and practice exercises designed for learning and experimenting with various Cloud, DevOps, and Kubernetes technologies.

## Overview

Each directory in this repository represents a self-contained lab or a group of related labs. The goal is to provide practical examples and scenarios that you can run on your own machine or in a cloud environment.

## Labs

This repository includes labs covering topics such as:

- **Kubernetes:** Core concepts, deployments, networking, storage, and security.
- **Infrastructure as Code (IaC):** Using tools like Terraform and Pulumi to manage infrastructure and application configurations.
- **CI/CD:** Building continuous integration and delivery pipelines.
- **Service Mesh:** Exploring service mesh functionality with tools like Istio.
- **Monitoring & Observability:** Setting up monitoring, logging, and tracing for applications.

_You can find a specific lab by navigating to its directory. Each lab has its own `README.md` with detailed instructions._

### Example Structure

```
.
├── README.md
├── kubernetes-basics
│   ├── README.md
│   └── deployment.yaml
├── istio-mtls
│   ├── README.md
│   └── peer-authentication.yaml
└── ...
```

## Getting Started

### Prerequisites

While each lab has its own specific requirements, the following tools are commonly used across many of the exercises:

- Docker
- kubectl
- A local Kubernetes cluster like Kind or Minikube or Rancher Desktop
- Helm
- A code editor like Visual Studio Code

Please refer to the `README.md` inside each lab's directory for a complete list of prerequisites and setup instructions.

## Contributing

Contributions are welcome! If you have an idea for a new lab, find a bug, or have a suggestion for improvement, please feel free to open an issue or submit a pull request.
