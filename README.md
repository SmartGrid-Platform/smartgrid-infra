<div align="center">

# smartgrid-infra

**Infrastructure repository — SmartGrid Utility Management Platform**

[![Infrastructure Pipeline](https://github.com/SmartGrid-Platform/smartgrid-infra/actions/workflows/infra.yml/badge.svg?branch=main)](https://github.com/SmartGrid-Platform/smartgrid-infra/actions/workflows/infra.yml)
[![Bootstrap](https://github.com/SmartGrid-Platform/smartgrid-infra/actions/workflows/bootstrap.yml/badge.svg?branch=main)](https://github.com/SmartGrid-Platform/smartgrid-infra/actions/workflows/bootstrap.yml)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![EKS](https://img.shields.io/badge/Kubernetes-EKS-326CE5?logo=kubernetes)](https://aws.amazon.com/eks/)

</div>

---

## What Is This Repository?

This repository contains all **infrastructure-as-code** for the SmartGrid Platform, provisioned on AWS using Terraform and bootstrapped via GitHub Actions. It owns:

- The complete **AWS cloud stack** (VPC, EKS, RDS, CloudFront, WAF, S3, SNS, SQS, Lambda, Secrets Manager, IAM)
- **Terraform Workspaces** (`default` = dev, `prod`) for environment parity
- **ArgoCD Application manifests** that register the Helm-based deployments in the cluster
- **Three GitHub Actions workflows**: infrastructure plan/apply, cluster bootstrap, and EKS deployment

> **Application code:** See [smartgrid-app](https://github.com/SmartGrid-Platform/smartgrid-app).  
> **Kubernetes Helm charts:** See [smartgrid-helm](https://github.com/SmartGrid-Platform/smartgrid-helm).

---

## Repository Structure

```
smartgrid-infra/
│
├── terraform/
│   ├── backend-setup/          # One-time bootstrap: S3 state bucket + DynamoDB lock table
│   │   └── main.tf
│   ├── modules/
│   │   └── smartgrid-core/     # All AWS resources (22 .tf files)
│   │       ├── vpc.tf
│   │       ├── eks.tf
│   │       ├── rds.tf
│   │       ├── alb.tf
│   │       ├── cloudfront.tf   # CloudFront distribution + WAFv2 Web ACL
│   │       ├── s3.tf           # Frontend bucket + Bills bucket (KMS encrypted)
│   │       ├── secrets_manager.tf
│   │       ├── lambda_sns.tf   # Lambda functions + SNS topics
│   │       ├── sqs.tf          # SQS queues + dead-letter queues
│   │       ├── iam.tf          # IAM roles, policies, IRSA bindings
│   │       ├── security_groups.tf
│   │       ├── instances.tf    # Optional bastion EC2
│   │       ├── helm.tf         # AWS Load Balancer Controller (Helm install via null_resource)
│   │       ├── monitoring.tf   # CloudWatch alarms
│   │       ├── guardduty.tf    # Optional threat detection
│   │       ├── cloudtrail.tf   # API audit logging
│   │       ├── backup.tf       # Automated RDS backup policies
│   │       ├── null_resources.tf
│   │       ├── outputs.tf
│   │       ├── providers.tf
│   │       ├── sqs.tf
│   │       └── variables.tf
│   ├── backend.tf              # S3 remote state configuration
│   ├── main.tf                 # Invokes smartgrid-core module
│   ├── outputs.tf              # Exports cluster name, ECR URL, ALB DNS, etc.
│   ├── providers.tf            # AWS (ap-south-1) + aliased us-east-1 for WAF
│   ├── variables.tf            # All input variable declarations
│   └── terraform.tfvars        # Non-sensitive defaults
│
├── argocd/
│   ├── application.yaml        # Dev environment ArgoCD Application
│   └── application-prod.yaml   # Production ArgoCD Application
│
└── .github/workflows/
    ├── infra.yml               # Terraform plan / apply / destroy
    ├── bootstrap.yml           # One-time cluster initialisation
    └── deploy-eks.yml          # Frontend S3 upload + CloudFront switch
```

---

## AWS Infrastructure Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AWS  (ap-south-1)                                    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  VPC  10.0.0.0/16                                                    │   │
│  │                                                                      │   │
│  │  ┌────────────────────┐   ┌────────────────────┐                    │   │
│  │  │  public-a          │   │  public-b           │                    │   │
│  │  │  10.0.1.0/24  AZ-0 │   │  10.0.2.0/24  AZ-1 │                    │   │
│  │  │  [NAT Gateway]     │   │                     │                    │   │
│  │  └────────────────────┘   └────────────────────┘                    │   │
│  │                                                                      │   │
│  │  ┌────────────────────┐   ┌────────────────────┐                    │   │
│  │  │  private-app-a     │   │  private-app-b      │                    │   │
│  │  │  10.0.11.0/24 AZ-0 │   │  10.0.12.0/24 AZ-1 │  ← EKS Pods      │   │
│  │  └────────────────────┘   └────────────────────┘                    │   │
│  │                                                                      │   │
│  │  ┌────────────────────┐   ┌────────────────────┐                    │   │
│  │  │  private-db-a      │   │  private-db-b       │                    │   │
│  │  │  10.0.21.0/24 AZ-0 │   │  10.0.22.0/24 AZ-1 │  ← RDS           │   │
│  │  └────────────────────┘   └────────────────────┘                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Edge:     CloudFront CDN  +  WAFv2 (rate limit 2,000 req/5min/IP)          │
│  Compute:  EKS Cluster  →  SPOT Node Group (t3.small)                       │
│  Data:     RDS MySQL 8.0  (db.t3.micro, 20–50 GB)                           │
│  Secrets:  AWS Secrets Manager  (single secret: smartgrid-{env}/config)     │
│  Storage:  S3 Frontend Bucket  +  S3 Bills Bucket (KMS encrypted)           │
│  Messaging:SNS (2 topics)  →  SQS (2 queues + 2 DLQs)                      │
│  Compute:  Lambda × 3  (unit_calculator, tariff_engine, bill_generator)     │
│  AI:       AWS Bedrock  (Nova Pro primary, Nova Lite fallback)               │
│  Security: GuardDuty (optional)  +  CloudTrail  +  VPC Flow Logs            │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Terraform Configuration

### Remote State

Before any `terraform apply`, run the bootstrap once to create the state backend:

```bash
cd terraform/backend-setup
terraform init && terraform apply
# Outputs: state_bucket_name, dynamodb_table_name
```

This creates:
- **S3 Bucket** (`smartgrid-tf-state-<suffix>`) — versioned, AES256, public access blocked
- **DynamoDB Table** (`smartgrid-tf-locks-<suffix>`) — PAY_PER_REQUEST, used for concurrent-apply locking

### Input Variables (`variables.tf` / `terraform.tfvars`)

**Non-sensitive defaults (`terraform.tfvars`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `ap-south-1` | AWS deployment region |
| `environment` | `default` | Environment name (used in all resource names) |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `instance_type` | `t2.micro` | Bastion EC2 instance type |
| `eks_node_instance_type` | `t3.small` | EKS worker node type (minimum) |
| `db_instance_class` | `db.t3.micro` | RDS instance class |
| `asg_min_size` | `1` | EKS node group minimum |
| `asg_max_size` | `1` | EKS node group maximum |
| `enable_guardduty` | `false` | Enable GuardDuty (requires active AWS billing) |
| `enable_bastion` | `false` | Create bastion EC2 (use SSM Session Manager instead) |
| `bedrock_primary_model` | `us.amazon.nova-pro-v1:0` | Primary AI model |
| `bedrock_fallback_model` | `us.amazon.nova-lite-v1:0` | Fallback AI model |
| `k8s_namespace` | `production` | Kubernetes namespace for SmartGrid pods |

**Sensitive values (set as `TF_VAR_*` environment variables — never in `terraform.tfvars`):**

| Variable | GitHub Secret | Description |
|----------|--------------|-------------|
| `db_password` | `TF_VAR_RDS_PASSWORD` | RDS master password |
| `jwt_secret` | `TF_VAR_JWT_SECRET` | JWT signing secret |
| `admin_password` | `TF_VAR_ADMIN_PASSWORD` | Bootstrap admin password |
| `smtp_user` | `TF_VAR_SMTP_USER` | SMTP username (optional) |
| `smtp_pass` | `TF_VAR_SMTP_PASS` | SMTP password (optional) |
| `notification_email` | `TF_VAR_NOTIFICATION_EMAIL` | SNS subscription email (optional) |

### Terraform Outputs (`outputs.tf`)

These values are consumed by CI/CD workflows and the bootstrap script:

| Output | Used By |
|--------|---------|
| `cloudfront_url` | Frontend access URL |
| `alb_dns` | API endpoint (before EKS migration) |
| `eks_cluster_name` | bootstrap.yml, deploy-eks.yml |
| `eks_cluster_endpoint` | kubectl config |
| `ecr_registry_url` | smartgrid-app CI (image push destination) |
| `rds_endpoint` | Injected into Secrets Manager |
| `eks_pod_role_arn` | Helm values (IRSA annotation) |
| `lbc_role_arn` | AWS Load Balancer Controller |
| `autoscaler_role_arn` | Cluster Autoscaler |
| `secrets_manager_secret_name` | Bootstrap + microservices |
| `k8s_namespace` | ArgoCD Application destination |

---

## Module: `smartgrid-core`

The `terraform/modules/smartgrid-core` module creates the entire AWS stack. Below is a full breakdown of every component.

---

### Networking (vpc.tf)

**VPC:** `10.0.0.0/16` with DNS support and DNS hostnames enabled. VPC Flow Logs enabled (CloudWatch, 30-day retention).

**Subnets (6 across 2 AZs):**

| Subnet | CIDR | AZ | Purpose | ELB Tags |
|--------|------|----|---------|----------|
| public-a | 10.0.1.0/24 | AZ-0 | NAT Gateway, IGW routing | `elb = 1` |
| public-b | 10.0.2.0/24 | AZ-1 | HA standby | `elb = 1` |
| private-app-a | 10.0.11.0/24 | AZ-0 | EKS pods | `internal-elb = 1` |
| private-app-b | 10.0.12.0/24 | AZ-1 | EKS pods | `internal-elb = 1` |
| private-db-a | 10.0.21.0/24 | AZ-0 | RDS primary | — |
| private-db-b | 10.0.22.0/24 | AZ-1 | RDS standby | — |

**Routing:**
- Public subnets → Internet Gateway (IGW)
- Private-app subnets → NAT Gateway (single, in public-a; EIP allocated)
- Private-db subnets → NAT Gateway (for managed RDS traffic)

---

### Kubernetes — EKS (eks.tf)

**Cluster:**
- Name: `smartgrid-{environment}-cluster`
- Control plane logs: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler` (CloudWatch, 7-day retention)
- Endpoint: Public (accessible from CI runners and `kubectl`)

**Node Group:**
- Capacity type: **SPOT** (70% cost reduction vs On-Demand)
- Instance type: `t3.small` minimum (configurable)
- Scaling: 1–1 by default (configurable via variables)
- Subnets: private-app-a, private-app-b
- Tagged for Cluster Autoscaler discovery

**OIDC / IRSA:** OIDC provider created for the cluster, enabling Kubernetes ServiceAccounts to assume AWS IAM roles at the pod level.

**IAM Roles for Service Accounts (IRSA):**

| Role | Attached To | Permissions |
|------|------------|-------------|
| `eks-pod-role` | `smartgrid-sa` (production namespace) | S3, Secrets Manager, KMS, Lambda, SNS, Bedrock, Textract |
| `aws-lb-controller` | `aws-load-balancer-controller` (kube-system) | EC2, ELB, WAFv2, IAM — all ALB/NLB provisioning actions |
| `cluster-autoscaler` | `cluster-autoscaler` (kube-system) | Read all ASGs; SetDesiredCapacity / TerminateInstance on tagged ASGs only |

**ECR Repositories (7, one per service + frontend):**

`smartgrid-{env}-auth-service`, `consumer-service`, `meter-service`, `billing-service`, `alert-service`, `ai-assistant-service`, `frontend`

All have **image scanning on push** enabled.

---

### Database — RDS (rds.tf)

| Parameter | Value |
|-----------|-------|
| Engine | MySQL 8.0 |
| Identifier | `smartgrid-{env}-rds-db` |
| Instance class | `db.t3.micro` (configurable) |
| Storage | 20 GB initial, auto-scales to 50 GB (gp2) |
| Subnets | private-db-a, private-db-b |
| Security group | `db-sg` — allows 3306 from `backend-sg` and EKS cluster SG only |
| Multi-AZ | `false` (enable for production HA) |
| Final snapshot | Skipped (demo setting) |

---

### Load Balancing — ALB (alb.tf)

**External Application Load Balancer:**
- Name: `smartgrid-{env}-external-alb`
- Scheme: Internet-facing, public subnets
- Listener: Port 80 HTTP
- Default action: 404 fixed response (all traffic routed via rules)

**Target groups and listener rules:**

| Priority | Path Pattern | Service | Port |
|----------|-------------|---------|------|
| 10 | `/api/auth*` | auth-service | 3001 |
| 20 | `/api/consumers*` | consumer-service | 3002 |
| 30 | `/api/meters*` | meter-service | 3003 |
| 40 | `/api/bills*`, `/api/tariffs*`, `/api/recharges*` | billing-service | 3004 |
| 50 | `/api/alerts*`, `/api/inspections*` | alert-service | 3005 |
| 60 | `/api/assistant*` | ai-assistant-service | 4004 |

**Health checks:** 15s interval, 3s timeout, 2 healthy / 2 unhealthy thresholds. Path: `/health`.

> **Note:** After EKS bootstrap, CloudFront origin switches from this ALB to the EKS-managed ALB (`smartgrid-default-eks-alb`) provisioned by the AWS Load Balancer Controller.

---

### CDN & Security — CloudFront + WAFv2 (cloudfront.tf)

**CloudFront Distribution:**
- IPv6: Enabled
- Default root object: `index.html`
- WAF Web ACL attached

**Origins:**

| Origin | Domain | Purpose |
|--------|--------|---------|
| S3-Frontend | S3 regional endpoint | React SPA static assets (OAC signed) |
| ALB-API | ALB DNS name (or EKS ALB post-migration) | API traffic routing |

**Cache behaviors:**

| Path | Origin | Methods | TTL | Notes |
|------|--------|---------|-----|-------|
| `/api/*` | ALB-API | All (GET/POST/PUT/DELETE/PATCH) | **0** (no cache) | Forwards: Authorization, Content-Type, Host, Origin, all cookies |
| `/*` (default) | S3-Frontend | GET, HEAD, OPTIONS | 3,600s default | Serves React build artifacts |

**Custom error responses (SPA routing):**
- 403 → `/index.html` (HTTP 200)
- 404 → `/index.html` (HTTP 200)

**WAFv2 Web ACL** (deployed in `us-east-1` — CloudFront scope requirement):
- Rule: `IPRateLimit` — 2,000 requests per 5 minutes per IP → Block
- Default action: Allow

---

### Storage — S3 + KMS (s3.tf)

**Frontend Bucket** (`smartgrid-{env}-frontend-bucket-{suffix}`)
- Public access: Blocked
- Access: CloudFront OAC (SigV4 signed requests only)
- Contains React Vite build artifacts

**Bills Bucket** (`smartgrid-{env}-bills-bucket-{suffix}`)
- Public access: Blocked
- Encryption: Customer-managed KMS key with auto-rotation
- Lifecycle policy:
  - 30 days → `STANDARD_IA`
  - 90 days → `GLACIER`
  - 365 days → Expire (permanent delete)

**KMS Key** (`smartgrid-{env}-s3-kms-key`): Customer-managed, alias `alias/smartgrid-s3-key`, auto-rotation enabled.

---

### Secrets Management (secrets_manager.tf)

**Single Secrets Manager secret:** `smartgrid-{env}/config`

Stores all 50+ runtime configuration parameters as JSON — injected into EKS pods at startup via `AWS_SECRET_NAME` environment variable and the `eks-pod-role` IRSA binding.

**Secret structure (representative):**

```json
{
  "DB_HOST":                  "<rds-endpoint>",
  "DB_PORT":                  "3306",
  "DB_NAME":                  "smartgrid",
  "DB_USER":                  "smartgrid_user",
  "DB_PASSWORD":              "<sensitive>",
  "JWT_SECRET":               "<sensitive>",
  "AWS_REGION":               "ap-south-1",
  "S3_BUCKET_NAME":           "smartgrid-default-bills-bucket-<suffix>",
  "LAMBDA_UNIT_CALCULATOR":   "smartgrid-default-unit-calculator-<suffix>",
  "LAMBDA_BILL_GENERATOR":    "smartgrid-default-bill-generator-<suffix>",
  "LAMBDA_TARIFF_ENGINE":     "smartgrid-default-tariff-engine-<suffix>",
  "SNS_LOW_BALANCE_ARN":      "arn:aws:sns:ap-south-1:...",
  "SNS_DISCONNECTION_ARN":    "arn:aws:sns:ap-south-1:...",
  "SQS_LOW_BALANCE_URL":      "https://sqs.ap-south-1...",
  "SQS_DISCONNECTION_URL":    "https://sqs.ap-south-1...",
  "BEDROCK_MODEL_PRIMARY":    "us.amazon.nova-pro-v1:0",
  "BEDROCK_MODEL_FALLBACK":   "us.amazon.nova-lite-v1:0",
  "SMTP_HOST":                "<smtp-host>",
  "SMTP_PORT":                "<smtp-port>",
  "SMTP_USER":                "<smtp-user>",
  "SMTP_PASS":                "<sensitive>",
  "SENDER_EMAIL":             "<sender>",
  "K8S_NAMESPACE":            "production"
}
```

---

### Messaging — Lambda + SNS + SQS (lambda_sns.tf, sqs.tf)

**Lambda Functions (3):**

| Function | Runtime | Purpose |
|----------|---------|---------|
| `smartgrid-{env}-unit-calculator` | Node.js 18.x | Compute kWh from reading delta |
| `smartgrid-{env}-tariff-engine` | Node.js 18.x | Resolve monetary rate per unit |
| `smartgrid-{env}-bill-generator` | Node.js 18.x | Generate PDF invoice, upload to S3 |

All functions: versioning enabled, publish=true. bill-generator has S3/KMS permissions.

**SNS Topics (2):**

| Topic | Trigger | Subscriptions |
|-------|---------|---------------|
| `smartgrid-{env}-low-balance-alerts` | Consumer balance drops below ₹15 | SQS queue + optional email |
| `smartgrid-{env}-disconnection-notices` | Consumer balance reaches ₹0 | SQS queue + optional email |

**SQS Queues (2 main + 2 DLQs):**

| Queue | Visibility Timeout | Retention | DLQ Threshold |
|-------|------------------|-----------|---------------|
| `low-balance-queue` | 60s | 1 day | 3 receive attempts → DLQ |
| `disconnection-queue` | 60s | 1 day | 3 receive attempts → DLQ |
| `low-balance-dlq` | — | 14 days | — |
| `disconnection-dlq` | — | 14 days | — |

---

### IAM & Security Groups (iam.tf, security_groups.tf)

**IAM Roles:**

| Role | Principal | Permissions |
|------|----------|-------------|
| EKS Cluster Role | eks.amazonaws.com | AmazonEKSClusterPolicy |
| EKS Node Role | ec2.amazonaws.com | AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, ECR ReadOnly |
| EKS Pod Role (IRSA) | EKS OIDC (smartgrid-sa) | S3, Secrets Manager, KMS, Lambda, SNS, Bedrock, Textract |
| LBC Role (IRSA) | EKS OIDC (aws-load-balancer-controller) | 200+ EC2/ELB/WAFv2 actions |
| Cluster Autoscaler (IRSA) | EKS OIDC | Read all ASGs; write only to tagged ASGs |
| Backend Role | ec2.amazonaws.com | Same as Pod Role + SSM managed instance |

**Security Groups:**

| SG | Ingress | Egress |
|----|---------|--------|
| `alb-sg` | HTTP 80 from 0.0.0.0/0 | All |
| `backend-sg` | SSH 22 from bastion-sg; ports 3001–3005, 4004 from alb-sg | All |
| `db-sg` | MySQL 3306 from backend-sg, EKS cluster SG | All |
| `bastion-sg` | None (SSM only) | All |

---

### Optional Components

**Bastion Host (instances.tf):** Amazon Linux 2, t2.micro, public-a subnet. Disabled by default (`enable_bastion=false`). Use AWS SSM Session Manager instead.

**GuardDuty (guardduty.tf):** Threat detection for S3, EKS audit logs, and EBS volumes. Disabled by default (`enable_guardduty=false`).

**CloudTrail (cloudtrail.tf):** API audit trail for all AWS service calls.

**AWS Backup (backup.tf):** Automated RDS snapshot policies.

**AWS LBC (helm.tf):** Installs `eks/aws-load-balancer-controller` v1.8.1 via Helm using `null_resource` + `local-exec`. Creates ServiceAccount with IRSA annotation, waits for node readiness, uninstalls before cluster destroy.

---

### Monitoring — CloudWatch Alarms (monitoring.tf)

| Alarm | Metric | Threshold | Period |
|-------|--------|-----------|--------|
| RDS CPU | `CPUUtilization` | > 80% | 5 min (2 periods) |
| RDS Connections | `DatabaseConnections` | > 50 | 5 min (2 periods) |
| RDS Storage | `FreeStorageSpace` | < 2 GB | 5 min (1 period) |
| ALB 5XX | `HTTPCode_ELB_5XX_Count` | > 10 | 5 min |

> Container Insights is disabled due to the 11-pod ENI limit on t3.small nodes.

---

## ArgoCD Applications

### `argocd/application.yaml` — Dev Environment

Deployed to EKS via `kubectl apply` during bootstrap. Watches `smartgrid-helm:dev`.

```yaml
spec:
  source:
    repoURL: https://github.com/SmartGrid-Platform/smartgrid-helm.git
    targetRevision: dev
    path: helm/smartgrid
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### `argocd/application-prod.yaml` — Production

Targets the `production` namespace. Merges `values.yaml` + `values-prod.yaml`. Self-heal enabled; prune disabled.

```yaml
ignoreDifferences:
  - kind: Secret
    name: smartgrid-secrets
    jsonPointers: [/data]
  - kind: ConfigMap
    name: smartgrid-config
    jsonPointers: [/data]
```

The `ignoreDifferences` block prevents ArgoCD from flagging Secret/ConfigMap drift — these are managed externally by the bootstrap script reading from Secrets Manager.

---

## GitHub Actions Workflows

### `infra.yml` — Terraform Plan / Apply / Destroy

**Triggers:** Push to `main` with changes in `terraform/`, or manual dispatch with `action` input (plan / apply / destroy).

**Plan job:** `terraform fmt`, `validate`, `plan` — outputs to GitHub step summary.

**Apply job:** Idempotent import loop before apply (re-imports pre-existing AWS resources to avoid drift conflicts), then `terraform apply`.

**Required GitHub Secrets:**

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TF_VAR_RDS_PASSWORD
TF_VAR_JWT_SECRET
TF_VAR_ADMIN_PASSWORD
TF_VAR_SMTP_USER        (optional)
TF_VAR_SMTP_PASS        (optional)
TF_VAR_NOTIFICATION_EMAIL (optional)
```

**Required GitHub Variables:**

```
TF_STATE_BUCKET
TF_STATE_LOCK_TABLE
AWS_REGION
```

---

### `bootstrap.yml` — One-Time Cluster Initialisation

Run **once** after `terraform apply` completes. Manual trigger only.

**Steps:**
1. Reads Terraform outputs (cluster name, namespace, IRSA role ARNs)
2. Updates kubeconfig
3. Installs **ArgoCD** via Helm (argocd namespace)
4. Installs **AWS Load Balancer Controller** via Helm (kube-system)
5. Installs **Cluster Autoscaler** via Helm (kube-system)
6. Creates `smartgrid-secrets` Secret from AWS Secrets Manager
7. Creates `smartgrid-config` ConfigMap
8. Applies ArgoCD Application manifests (dev + prod)
9. Waits for ArgoCD sync
10. Retrieves EKS ALB DNS from Load Balancer Controller
11. Runs `terraform apply -var eks_alb_dns=<alb-dns>` to switch CloudFront origin to EKS

**Additional required GitHub Variables:**

```
ORG_GITHUB
ARGOCD_CHART_VERSION
CLUSTER_AUTOSCALER_CHART_VER
CLUSTER_AUTOSCALER_IMAGE_TAG
```

---

### `deploy-eks.yml` — Frontend + Security Scans

**Trigger:** Push to `dev` or manual dispatch.

**Jobs:**
1. **read-tf-outputs** — Reads cluster name, ECR URL, secret name from Terraform state
2. **security-scans** — Checkov IaC scan + Trivy filesystem scan (both non-blocking, soft-fail)
3. **upload-frontend** — `npm run build` (Vite) → `aws s3 sync` → CloudFront cache invalidation

---

## Full Deployment Walkthrough

### Step 1 — Bootstrap remote state (once)

```bash
cd terraform/backend-setup
terraform init
terraform apply
# Note: state_bucket_name and dynamodb_table_name from outputs
```

### Step 2 — Configure GitHub Secrets and Variables

In `smartgrid-infra` → Settings → Secrets and variables → Actions:

**Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `TF_VAR_RDS_PASSWORD`, `TF_VAR_JWT_SECRET`, `TF_VAR_ADMIN_PASSWORD`

**Variables:** `TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`, `AWS_REGION`, `ORG_GITHUB`, `ARGOCD_CHART_VERSION`, `CLUSTER_AUTOSCALER_CHART_VER`, `CLUSTER_AUTOSCALER_IMAGE_TAG`

### Step 3 — Deploy infrastructure

GitHub Actions → **Infrastructure Pipeline** → Run workflow → `action: apply`

Monitor the plan in the GitHub step summary. The workflow runs `terraform apply` automatically.

### Step 4 — Bootstrap the cluster

GitHub Actions → **Bootstrap Cluster (ArgoCD + Controllers + Secrets)** → Run workflow

This installs ArgoCD, LBC, Cluster Autoscaler, creates the secrets/configmap, registers ArgoCD Applications, and switches CloudFront to EKS ALB.

### Step 5 — Verify

```bash
aws eks update-kubeconfig --name smartgrid-default-cluster --region ap-south-1

kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n production
argocd app list
```

---

## Resource Inventory

| Resource | Count | Details |
|----------|-------|---------|
| VPCs | 1 | 10.0.0.0/16 |
| Subnets | 6 | 2 public + 2 private-app + 2 private-db |
| NAT Gateways | 1 | Single (cost-efficient) |
| EKS Clusters | 1 | SPOT node group |
| ECR Repositories | 7 | One per service + frontend |
| RDS Instances | 1 | MySQL 8.0, db.t3.micro, 20–50 GB |
| ALBs | 1 | Internet-facing (+ 1 EKS-managed post-bootstrap) |
| Target Groups | 7 | 6 services + AI assistant |
| S3 Buckets | 2 | Frontend (OAC) + Bills (KMS) |
| KMS Keys | 1 | Bills bucket encryption |
| Lambda Functions | 3 | Unit calc, tariff engine, bill generator |
| SNS Topics | 2 | Low balance + disconnection |
| SQS Queues | 4 | 2 main + 2 DLQs |
| Secrets Manager Secrets | 1 | 50+ runtime parameters |
| Security Groups | 4 | ALB, backend, DB, bastion |
| IAM Roles | 10+ | Cluster, nodes, pods (IRSA), LBC, autoscaler |
| CloudFront Distributions | 1 | CDN + WAFv2 |
| WAF Web ACLs | 1 | Rate limiting |
| CloudWatch Alarms | 4 | RDS CPU/connections/storage, ALB 5XX |

---

## Cost Considerations

| Decision | Savings | Trade-off |
|----------|---------|-----------|
| SPOT node group | ~70% vs On-Demand | Nodes can be interrupted (Cluster Autoscaler replaces) |
| Single NAT Gateway | ~50% vs per-AZ NAT | Single point of egress failure |
| RDS Multi-AZ disabled | ~100% (doubles cost) | No automatic failover in dev |
| GuardDuty disabled | ~$30–50/month | No threat detection until enabled |
| S3 Glacier lifecycle | Storage cost reduction | Bills older than 90 days in cold storage |

---

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [smartgrid-app](https://github.com/SmartGrid-Platform/smartgrid-app) | Application source — React frontend, 6 Node.js microservices, Lambda functions |
| [smartgrid-helm](https://github.com/SmartGrid-Platform/smartgrid-helm) | Helm charts and ArgoCD GitOps manifests for Kubernetes delivery |

## 🚀 Application Overview

The **SmartGrid Platform** is designed to modernize utility management. It provides a secure portal for consumers to check usage, recharge balances, and view bills, while offering an administrative dashboard for utility staff to provision smart meters, record consumption readings, and manage dynamic tariffs.

### Architecture Highlights
- **Frontend**: React.js SPA (Vite)
- **Backend Microservices**: Node.js, Express, Sequelize ORM
- **Database**: Managed Relational Database (MySQL)
- **Asynchronous Processing**: Serverless Event-Driven compute
- **Infrastructure as Code**: Fully automated deployment via Terraform

---

## ☁️ Cloud Infrastructure & Services Incorporated

This application is deployed entirely on AWS using a highly secure, modular architecture with separate `dev` and `prod` environments managed by **Terraform Workspaces**.

### Edge & Content Delivery
* **Amazon CloudFront**: Acts as the global CDN and reverse proxy. It serves the static React frontend from S3 with ultra-low latency and seamlessly routes `/api/*` requests directly to the internal Load Balancer.
* **AWS WAFv2**: Web Application Firewall attached to CloudFront protecting the platform from DDoS attacks, SQL injection, and rate-limiting abusive IP addresses.

### Compute & Microservices
* **Application Load Balancer (ALB)**: Public-facing entry point for API traffic. Dynamically routes incoming HTTP requests to the appropriate Target Groups for each specific microservice.
* **EC2 Auto Scaling Group (ASG)**: Hosts the Node.js backend. Instances run in Private Subnets for security. They utilize a custom `user_data.sh` script to automatically install dependencies, pull the latest code, execute database migrations, and boot up 5 PM2 microservices on startup.
* **NAT Gateway**: Allows EC2 instances in private subnets to securely download packages and contact external AWS APIs without exposing them to inbound internet traffic.

### Serverless Lambdas (In-built Modules)
To prevent the main API servers from bogging down during heavy operations, intensive tasks are offloaded to **AWS Lambda**:
1. **`smartgrid-unit-calculator`**: Triggered when a new meter reading is submitted. It instantly calculates the consumed units.
2. **`smartgrid-tariff-engine`**: Calculates the monetary cost of the consumed units based on the consumer's active tariff rate and tier.
3. **`smartgrid-bill-generator`**: Generates a PDF/HTML monthly invoice statement and securely uploads it to an S3 bucket for consumer retrieval.

### Event-Driven Alerts
* **Amazon SNS (Simple Notification Service)**: Integrated directly into the backend code. 
  - **Low Balance Alerts**: If a meter deduction causes a consumer's balance to drop below ₹15, the API fires an event to the `low-balance` SNS topic, which asynchronously sends warning emails to the consumer.
  - **Disconnection Notices**: If the balance drops below ₹0, an event is sent to the `disconnection` SNS topic.

### Storage & Security
* **Amazon S3 (Simple Storage Service)**: 
  - **Frontend Bucket**: Hosts the React UI. Completely private, accessible only via CloudFront Origin Access Control (OAC).
  - **Bills Bucket**: Securely stores generated monthly invoices.
* **Amazon RDS (MySQL)**: Fully managed, Multi-AZ relational database residing in isolated database subnets.
* **AWS Secrets Manager**: Eliminates hardcoded passwords. The database credentials and JWT signing keys are stored here and dynamically injected into the EC2 instances at runtime.
* **Terraform Remote State (S3 & DynamoDB)**: Infrastructure state is securely stored in a remote S3 bucket, with state-locking managed by a DynamoDB table to prevent concurrent modification errors across development teams.

---

## 🏗️ Project Structure

The repository is organized into distinct domains:

```text
/frontend          # React SPA (Consumer Portal & Staff Dashboard)
/services
  /auth-service      # JWT Authentication, Staff/Consumer Roles
  /consumer-service  # Consumer Profiles, History
  /meter-service     # Meter Provisioning, Readings, Direct Balance Deductions
  /billing-service   # Tariffs, Payments, Recharges
  /alert-service     # Dashboard Notifications
/lambdas
  /unit_calculator   # Lambda: Calculates units
  /tariff_engine     # Lambda: Resolves tariff price
  /bill_generator    # Lambda: Creates statements
/shared            # Shared database models and migrations
/terraform
  /backend-setup     # Bootstraps the S3 remote state and DynamoDB locks
  /modules
    /smartgrid-core  # Reusable module containing the entire AWS architecture
  main.tf            # Workspace environment orchestration
```

## 🛠️ Automated Deployment (Terraform)

The infrastructure is 100% automated. Deployment requires zero manual SSH intervention.

1. `terraform init` (Initializes S3 backend)
2. `terraform workspace select dev` (Select environment)
3. `terraform apply`

**What happens on apply?**
- Terraform builds the VPC, Database, ASG, and CDN.
- Terraform executes a `local-exec` provisioner that compiles the Vite React app (`npm run build`) and uploads it to the S3 bucket.
- The EC2 instances boot, clone this repository, fetch secrets, run database migrations, seed the initial `admin` user, and start the PM2 services.
- The CloudFront URL is outputted to the console for instant access.
