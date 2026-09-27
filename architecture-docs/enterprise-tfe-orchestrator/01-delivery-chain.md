---
title: "Platform Delivery Chain: How Code Becomes Infrastructure"
tags: [architecture, terraform, hcp-terraform, github-actions, gcp, onboarding]
created: 2026-09-27
status: draft
---

# Platform Delivery Chain

How a file edited on a developer workstation becomes a running resource inside Google Cloud.

This document walks through the full path: every machine, every network call, and
every authentication step in between. I have written it to be read in order, because
each layer only makes sense once the previous one is clear. Nothing here is magic;
each piece exists for a reason, and I explain that reason as we go.

---

## ★ The one idea that fixes most confusion

There are **two independent loops**, not one chain. Separating them is the single
most useful thing a reader can take from this document, because it explains why
a passing CI run and a running cloud environment are two different facts.

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","primaryBorderColor":"#30363d","lineColor":"#58a6ff","fontSize":"15px"}}}%%
flowchart LR
    subgraph CI["LOOP 1: QUALITY GATE"]
        A["git push"] --> B["GitHub"]
        B --> C["GitHub Actions<br/>fmt + validate"]
        C --> D{"Pass?"}
        D -->|No| E["PR blocked"]
        D -->|Yes| F["Ready to merge"]
    end

    subgraph CD["LOOP 2: DELIVERY"]
        B2["merge to dev"] --> G["GitHub webhook"]
        G --> H["HCP Terraform"]
        H --> I["plan"]
        I --> J["apply"]
        J --> K["GCP resources"]
    end

    C -.->|"merge button"| B2

    style CI fill:#161b22,stroke:#58a6ff,color:#c9d1d9
    style CD fill:#161b22,stroke:#3fb950,color:#c9d1d9
    style K fill:#1c2128,stroke:#3fb950,color:#3fb950
    style E fill:#2d1214,stroke:#f85149,color:#f85149
```

> **The misconception this section corrects:** it is natural to assume that a
> successful GitHub Actions run is what *deploys* the infrastructure. It is not.
> Actions only **validates** code. The infrastructure is created by HCP Terraform,
> which GitHub wakes with a **webhook** after a merge. Two separate systems, and
> neither one drives the other.

---

## The four hops, in order

The chain breaks into four hops. Each hop answers a different question: *how does
the code travel*, *who checks it*, *who decides to run*, and *who builds it*.

```mermaid
%%{init: {"theme":"dark","themeVariables":{"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","primaryBorderColor":"#58a6ff","lineColor":"#58a6ff","textColor":"#c9d1d9","actorBkg":"#161b22","actorTextColor":"#c9d1d9","actorBorder":"#58a6ff","noteBkgColor":"#1c2128","noteTextColor":"#c9d1d9","noteBorderColor":"#d29922","signalColor":"#8b949e","signalTextColor":"#c9d1d9","labelBoxBkgColor":"#1c2128","labelBoxBorderColor":"#30363d","labelTextColor":"#c9d1d9","loopTextColor":"#c9d1d9","fontSize":"14px"}}}%%
sequenceDiagram
    participant M as 💻 Developer Machine
    participant GH as 🐙 GitHub
    participant ACT as ⚙️ Actions Runner<br/>(ephemeral VM)
    participant TFC as 🏗️ HCP Terraform
    participant GCP as ☁️ Google Cloud

    Note over M,GCP: ── HOP 1: the developer pushes code ──
    M->>GH: git push (HTTPS + developer credentials)
    Note right of GH: Verifies the developer identity.<br/>Stores commit. Done.

    Note over GH,ACT: ── HOP 2: GitHub runs the configured checks ──
    GH->>ACT: internal trigger (no public call)
    ACT->>GH: git clone
    ACT->>ACT: terraform fmt -check
    ACT->>ACT: terraform init -backend=false
    ACT->>ACT: terraform validate
    ACT-->>GH: pass / fail

    Note over GH,GCP: ── HOP 3: webhook wakes HCP ──
    GH->>TFC: HTTPS POST (webhook payload)
    Note right of TFC: "branch dev changed.<br/>Start a run."
    TFC->>TFC: git clone the repository
    TFC->>TFC: reads enterprise-tfe-orchestrator/

    Note over TFC,GCP: ── HOP 4: HCP builds resources ──
    TFC->>GCP: OIDC token exchange (IAM STS)
    GCP-->>TFC: short-lived access token
    TFC->>GCP: REST API calls (compute, container, storage…)
    GCP-->>TFC: created resources
    TFC->>TFC: writes state to HCP's database
```

---

## Hop 1: Developer's machine → GitHub

| Question | Answer |
|---|---|
| **What travels?** | The `.tf` files, compressed inside a Git packfile |
| **Over what?** | HTTPS to `github.com` (port 443), TLS-encrypted |
| **How is the author identified?** | A credential helper (OS keychain) or an SSH key. GitHub verifies it, then trusts the push. |
| **What lands on GitHub?** | An immutable **commit** object. Nothing is executed. |

**Key point:** at this stage GitHub is purely a *version store*. It holds the code
and does nothing else with it. Execution happens strictly downstream.

---

## Hop 2: GitHub → Actions (the part that surprises people)

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","lineColor":"#58a6ff"}}}%%
flowchart TB
    A["PR opened / updated"] --> B{"paths filter<br/>matches?"}
    B -->|"no change in<br/>enterprise-tfe-orchestrator/"| C["Workflow skipped<br/>no runner used"]
    B -->|yes| D["GitHub provisions<br/>ubuntu-latest VM"]
    D --> E["Runner clones repo"]
    E --> F["Runs each step in order"]
    F --> G["Pass or Fail badge"]

    style C fill:#161b22,stroke:#8b949e,color:#8b949e
    style D fill:#161b22,stroke:#d29922,color:#d29922
    style G fill:#161b22,stroke:#3fb950,color:#3fb950
```

**What actually happens:**

1. GitHub **internally** registers the PR event. No internet call is involved;
   this is GitHub's own event bus, entirely inside their infrastructure.
2. The `paths:` filter is evaluated. If the workflow cannot be affected by the
   change, it is **skipped without consuming a single second of compute**.
3. GitHub provisions a **throwaway virtual machine** (`ubuntu-latest`). The code
   executes here, not on any developer's machine, and not on HCP Terraform.
4. That VM is **destroyed** when the job finishes. Nothing persists.

> **Why this separation is a security property, not a formality:** the Actions
> runner holds its own copy of the code and access to repository secrets. It is
> deliberately isolated from the deployment path. That isolation is precisely what
> makes it acceptable for CI to have read access while the CD system holds the
> write credentials.

---

## Hop 3: GitHub → HCP Terraform (the webhook)

This hop is the one most explanations skip, and it is the one that answers the
question *"how does the platform even know the code changed?"* The answer is a
**webhook**, not a pipeline.

**The mechanism:**

```mermaid
%%{init: {"theme":"dark","themeVariables":{"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","primaryBorderColor":"#58a6ff","lineColor":"#58a6ff","textColor":"#c9d1d9","actorBkg":"#161b22","actorTextColor":"#c9d1d9","actorBorder":"#58a6ff","noteBkgColor":"#1c2128","noteTextColor":"#c9d1d9","noteBorderColor":"#d29922","signalColor":"#8b949e","signalTextColor":"#c9d1d9","labelBoxBkgColor":"#1c2128","labelBoxBorderColor":"#30363d","labelTextColor":"#c9d1d9","loopTextColor":"#c9d1d9","fontSize":"14px"}}}%%
sequenceDiagram
    participant U as Developer
    participant GH as GitHub
    participant HOOK as HCP Webhook URL
    participant W as Workspace<br/>ws-HbPUo3znoyosCBgv
    participant RUN as Run Queue

    U->>GH: merge PR into dev
    GH->>HOOK: POST payload<br/>{ref: "refs/heads/dev", sha: "..."}
    Note over HOOK: URL contains a secret token.<br/>Unguessable = only GitHub can call it.
    HOOK->>W: "this repo/branch changed"
    W->>W: check branch == dev? ✓
    W->>W: check working dir ==<br/>enterprise-tfe-orchestrator? ✓
    W->>RUN: queue a run
    RUN->>RUN: clone, init, plan
```

**The three workspace settings that make this work:**

| Setting | Value | Why it exists |
|---|---|---|
| **Watched branch** | `dev` | Merges to `main` never trigger anything |
| **Working Directory** | `enterprise-tfe-orchestrator` | Enables a monorepo: every other folder in the repository is invisible to Terraform |
| **Apply Method** | `Auto apply` | Removes the manual "Apply" click after a successful plan |

> ★ **The Working Directory is the most consequential setting in the whole setup.**
> It is what allows Terraform, GitOps, and application code to share a single
> repository without interfering with one another. Terraform only ever reads
> `enterprise-tfe-orchestrator/`, and is structurally unable to see the rest.

---

## Hop 4: HCP Terraform → Google Cloud

This setup authenticates **without a stored key**, using keyless identity. It is the
most important section in this document, because this is precisely where a
long-lived credential is most often introduced by mistake, and then leaked.

### The credential chain

```mermaid
%%{init: {"theme":"dark","themeVariables":{"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","primaryBorderColor":"#3fb950","lineColor":"#3fb950","textColor":"#c9d1d9","actorBkg":"#161b22","actorTextColor":"#c9d1d9","actorBorder":"#3fb950","noteBkgColor":"#1c2128","noteTextColor":"#c9d1d9","noteBorderColor":"#d29922","signalColor":"#8b949e","signalTextColor":"#c9d1d9","labelBoxBkgColor":"#1c2128","labelBoxBorderColor":"#30363d","labelTextColor":"#c9d1d9","loopTextColor":"#c9d1d9","fontSize":"14px"}}}%%
flowchart TB
    subgraph TFCSIDE["HCP Terraform side: no secret stored"]
        RUN["Terraform Run<br/>identity: run-xxxx"]
        VAR["Workspace variables<br/>TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL<br/>TFC_GCP_WORKLOAD_PROVIDER_NAME"]
        RUN --> VAR
    end

    subgraph GCPSIDE["Google Cloud side"]
        POOL["Workload Identity Pool<br/>workloadIdentityPools/tfc-pool"]
        PROV["OIDC Provider<br/>issuer = HCP Terraform"]
        SA["Service Account<br/>tfc-terraform-runner"]
        BIND["IAM binding<br/>roles/iam.workloadIdentityUser"]
        ROLE["Project roles<br/>compute/networkAdmin, container.admin…"]
        POOL --> PROV --> SA --> BIND --> ROLE
    end

    VAR -->|"1. sends its own OIDC token"| POOL
    POOL -->|"2. verifies issuer + audience"| PROV
    PROV -->|"3. mints short-lived<br/>access token (~1h)"| RUN
    RUN -->|"4. calls APIs with that token"| ROLE

    style TFCSIDE fill:#161b22,stroke:#3fb950,color:#c9d1d9
    style GCPSIDE fill:#161b22,stroke:#58a6ff,color:#c9d1d9
    style ROLE fill:#1c2128,stroke:#3fb950,color:#3fb950
```

**In plain English:**

1. HCP Terraform asserts: *"this is a legitimate run, and it claims to act as this
   service account."* It proves the claim with a cryptographically signed token,
   no password, and no key file anywhere.
2. Google verifies three separate things: *is the issuer genuinely HCP Terraform?
   is the audience my identity pool? does the token's subject match the service
   account that was bound?*
3. Only if all three match does Google issue a **temporary access token**, valid
   for roughly one hour.
4. Terraform uses that token to call the GCP APIs. When the run finishes, the
   token simply expires and ceases to work.

> ★ **The security property:** there is **no key file anywhere in this design**.
> Nothing to leak, nothing to rotate, nothing to commit to Git by accident.
> Contrast this with the older pattern of downloading a `credentials.json`:
> that file is a permanent password in plaintext, and eliminating it is the entire
> reason this architecture exists.

### The environment variables doing the work

| Variable | Value | Meaning |
|---|---|---|
| `TF_CLI_ARGS_plan` | `-var-file=config/dev.tfvars` | "Every plan and apply reads answers from this file" |
| `TFC_GCP_PROVIDER_AUTH` | `true` | "Use dynamic credentials, not a static key" |
| `TFC_GCP_PRINCIPAL_TYPE` | `service_account` | "The identity is a service account" |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | the SA email | *Which* service account to impersonate |
| `TFC_GCP_WORKLOAD_PROVIDER_NAME` | `projects/…/providers/…` | *Where* to verify the token |

> **Note what is absent:** there is no `GOOGLE_CREDENTIALS` variable. That absence
> *is* the security property: there is no stored secret for an attacker to steal.

---

## What happens inside GCP: creation order

Terraform does not create resources in the order they appear in the source files. It
first builds a **dependency graph**, then creates parents strictly before children.

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","lineColor":"#58a6ff"}}}%%
flowchart TB
    subgraph W1["Wave 1: enable APIs (services.tf)"]
        S1["container.googleapis.com<br/>compute.googleapis.com<br/>storage.googleapis.com<br/>artifactregistry.googleapis.com"]
    end

    subgraph W2["Wave 2: the network skeleton (network.tf)"]
        N1["VPC network<br/><i>everything hangs off this</i>"]
        N2["Public subnet"]
        N3["Private subnet<br/>+ Flow Logs ← org policy"]
    end

    subgraph W3["Wave 3: independent services"]
        B1["Storage bucket<br/>(artifacts)"]
        R1["Artifact Registry<br/>(container images)"]
    end

    subgraph W4["Wave 4: compute (later stages)"]
        G1["Cloud NAT<br/>(egress for private nodes)"]
        G2["GKE cluster"]
        G3["Node pool"]
    end

    S1 --> N1
    N1 --> N2
    N1 --> N3
    N3 --> G1
    N1 --> G2
    G2 --> G3

    style W1 fill:#161b22,stroke:#d29922,color:#c9d1d9
    style W2 fill:#161b22,stroke:#58a6ff,color:#c9d1d9
    style W3 fill:#161b22,stroke:#8b949e,color:#c9d1d9
    style W4 fill:#161b22,stroke:#3fb950,color:#c9d1d9
    style N3 fill:#1c2128,stroke:#f0883e,color:#f0883e
```

**Why this order is forced:**

| Resource | Must exist first | Reason |
|---|---|---|
| APIs | n/a | Everything else calls these |
| VPC | APIs | Cannot create a network in a project without the API |
| Subnet | VPC | A subnet is *inside* a network |
| Cloud NAT | Private subnet | NAT attaches to a specific subnet |
| GKE cluster | VPC + subnet | The cluster's nodes must land in a subnet |
| Node pool | GKE cluster | A node pool is a child of a cluster |

> **A real failure from this project demonstrates the principle.** During the build
> of this environment, the private subnet was rejected with
> `Error 412: Constraint constraints/compute.requireVpcFlowLogs violated`. The
> organisation policy inherited by this project *requires* flow logs on every
> subnet; Terraform attempted to create the subnet without them and GCP refused.
>
> **The correct response to a guardrail is to satisfy it, never to disable it.**
> Adding Flow Logs at 100% sampling brought the configuration into compliance
> without weakening a control the platform team owns. Removing the policy would
> have been faster and would have silently degraded a security boundary.

---

## State: the concept most explanations omit

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9","lineColor":"#d29922"}}}%%
flowchart LR
    subgraph LOCAL["Developer Machine"]
        TF["Terraform CLI"]
        CACHE[".terraform/ folder<br/><i>provider plugins</i>"]
    end

    subgraph REMOTE["HCP Terraform: the source of truth"]
        ST[("State database<br/><b>what actually exists</b>")]
        LOCK[("Run lock<br/><i>one run at a time</i>")]
    end

    subgraph CLOUD["Google Cloud"]
        REAL[("Real resources<br/>VPC, bucket, registry…")]
    end

    TF -->|"reads state to build the plan"| ST
    ST -->|"apply: create / update / destroy"| REAL
    REAL -.->|"Terraform never reads<br/>this back: it trusts state"| ST
    LOCK -.->|"prevents two runs<br/>corrupting state"| ST

    style REMOTE fill:#161b22,stroke:#d29922,color:#c9d1d9
    style CLOUD fill:#161b22,stroke:#3fb950,color:#c9d1d9
```

> ★ **The rule that prevents the majority of infrastructure incidents:**
> **State behaves like a cache, but it is an authoritative one.** Terraform decides
> what to do by comparing *the configuration* against *state*, **not** against live
> reality. If a resource is deleted by hand in the GCP console, state still records
> it as existing, and Terraform's next plan becomes incorrect.
>
> For this reason, `terraform apply` must never be run from a developer machine
> against this project. State lives in HCP Terraform. Two writers means
> corruption.

---

## Current state of the environment

The following reflects what has already been provisioned, what comes next, and what
is planned for later stages.

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9"}}}%%
flowchart LR
    subgraph DONE["✅ Built"]
        D1["dev branch"]
        D2["HCP org + workspace<br/>ws-HbPUo3znoyosCBgv"]
        D3["WIF identity<br/>(pool, provider, SA)"]
        D4["bootstrap-tfc-gcp.sh"]
        D5["VPC + 2 subnets"]
        D6["Storage bucket"]
        D7["Artifact Registry"]
        D8["Actions workflow"]
    end

    subgraph NEXT["⏭️ Next"]
        N1["Cloud NAT"]
        N2["GKE cluster"]
        N3["Node pool"]
    end

    subgraph LATER["📦 Later"]
        L1["GKE via Terraform"]
        L2["Flux bootstrap"]
        L3["kube-prometheus-stack"]
        L4["Loki + Tempo"]
        L5["Grafana access"]
        L6["Sample app + traces"]
    end

    DONE ==> NEXT ==> LATER

    style DONE fill:#0f2417,stroke:#3fb950,color:#c9d1d9
    style NEXT fill:#1c2128,stroke:#d29922,color:#c9d1d9
    style LATER fill:#161b22,stroke:#8b949e,color:#8b949e
```

---

## The destination: the full observability stack

This is where the platform is heading, and how the individual components will
communicate once the cluster is running.

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","primaryColor":"#161b22","primaryTextColor":"#c9d1d9"}}}%%
flowchart TB
    subgraph IN["Inside GKE"]
        APP["Sample App<br/>:9090/metrics"]
        PODS["All Pods<br/>stdout logs"]
        OTEL["OTel SDK<br/>auto-injected"]
    end

    subgraph COLLECT["Collection layer"]
        PROM["Prometheus<br/><i>pulls /metrics every 15s</i>"]
        LOKIC["Log Collector<br/>Alloy / Promtail"]
        OTELC["OTel Collector<br/>:4317 gRPC, :4318 HTTP"]
    end

    subgraph STORE["Storage: self-hosted first"]
        TSDB[("Prometheus TSDB")]
        LOGDB[("Loki")]
        TRDB[("Tempo")]
    end

    subgraph VIEW["Presentation"]
        GRAF["Grafana<br/>one UI, three datasources"]
    end

    APP -->|"HTTP scrape"| PROM
    OTEL -->|"OTLP push"| OTELC
    PODS -->|"read files"| LOKIC
    PROM --> TSDB
    LOKIC --> LOGDB
    OTELC --> TRDB
    TSDB --> GRAF
    LOGDB --> GRAF
    TRDB --> GRAF

    style COLLECT fill:#161b22,stroke:#58a6ff,color:#c9d1d9
    style STORE fill:#161b22,stroke:#3fb950,color:#c9d1d9
    style VIEW fill:#161b22,stroke:#d29922,color:#c9d1d9
```

**The three data types, and why they move differently:**

| Type | Direction | Transport | Why different |
|---|---|---|---|
| **Metric** | Prometheus **pulls** from the app | HTTP `/metrics` | Cheap, stateless, can be retried |
| **Log** | Collector **pushes** to storage | Loki push API | High volume, must not block the app |
| **Trace** | App **pushes** to collector | OTLP (gRPC/HTTP) | Context must survive across services |

> **Why metrics are pulled while logs and traces are pushed:** a failed metric
> scrape is harmless: it simply produces a gap in the data. But if log shipping
> blocked an application response, the application itself would degrade. Logs and
> traces are therefore always fire-and-forget, pushed asynchronously, so that
> observability can never become an availability risk. This asymmetry is a
> deliberate design decision, not an accident.

---

## The three tools, side by side

| Tool | Owns | Triggered by | Runs on | Touches GCP? |
|---|---|---|---|---|
| **GitHub Actions** | Code quality | PR opened/updated | Ephemeral VM | ❌ Never |
| **HCP Terraform** | Infrastructure | Webhook from `dev` | HCP's workers | ✅ Creates/deletes |
| **Flux** | In-cluster state | Polls Git every 1 to 10 min | Inside the cluster | ✅ Via K8s API only |

> **Flux is deliberately absent from the two loops above.** It operates on an
> entirely separate path: it never passes through GitHub Actions or HCP Terraform.
> It reads Git on its own schedule and communicates directly with the Kubernetes
> API. Once the GitOps stages are reached, this separation is what prevents the
> three systems from interfering with one another.

---

## Vocabulary quick-reference

| Term | One-line meaning |
|---|---|
| **Commit** | An immutable snapshot of your files |
| **PR** | A request to merge one branch into another |
| **Workflow** | A YAML file describing automated checks |
| **Runner** | The throwaway VM that executes a workflow |
| **Webhook** | An HTTPS callback that tells another system "something changed" |
| **Plan** | A dry run: "here is exactly what I would change" |
| **Apply** | Actually making those changes |
| **State** | Terraform's record of what it believes exists |
| **Provider** | The plugin that knows how to talk to a cloud |
| **OIDC / WIF** | Keyless login: prove who you are with a token, not a password |
| **Dynamic credentials** | A temporary access token, minted per run, auto-expiring |

---

## Comprehension check

The following questions are useful for confirming the material has been absorbed. A
reader who can answer all five has understood the delivery chain end to end.

- [ ] Can you explain why GitHub Actions does **not** trigger the deployment?
- [ ] Can you name the four hops, and the distinct role of each?
- [ ] Do you know which single workspace setting makes the monorepo possible?
- [ ] Can you explain why state must never be written from two places?
- [ ] Can you explain why metrics are pulled while logs and traces are pushed?

---

## Related

- [[02-terraform-resource-map]]: every `.tf` file and what it creates
- [[03-gitops-flux-flow]]: the Flux reconciliation loop (following the bootstrap)
