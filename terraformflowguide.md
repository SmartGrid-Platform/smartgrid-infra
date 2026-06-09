# Terraform Flow & Infrastructure Guide

This document explains the complete lifecycle of how our AWS infrastructure is managed using Terraform. It serves as a comprehensive guide to understanding the workflow, the folder structure, and the core concepts implemented in the SmartGrid project.

---

## 📂 1. Terraform Folder Structure & Mapping

Our Terraform code is strictly organized to promote reusability and isolated environments.

```text
/terraform
â”œâ”€â”€ backend-setup/                  # Phase 1: Bootstraps the Remote State Backend
â”‚   â”œâ”€â”€ main.tf                     # Creates the S3 Bucket (for state files) & DynamoDB (for locking)
â”‚   â””â”€â”€ .terraform.lock.hcl         # Lock file for backend-setup dependencies
â”‚
â”œâ”€â”€ modules/                        
â”‚   â””â”€â”€ smartgrid-core/             # Phase 2: The Reusable Application Blueprint (Module)
â”‚       â”œâ”€â”€ vpc.tf                  # Defines Networking (VPC, Subnets, Gateways)
â”‚       â”œâ”€â”€ instances.tf            # Defines Compute (ASG, Launch Templates, Bastion)
â”‚       â”œâ”€â”€ rds.tf                  # Defines Database (MySQL)
â”‚       â”œâ”€â”€ alb.tf                  # Defines Application Load Balancer
â”‚       â”œâ”€â”€ cloudfront.tf           # Defines CDN and WAF (Web Application Firewall)
â”‚       â”œâ”€â”€ s3.tf                   # Defines Storage (Frontend bucket, Bills bucket)
â”‚       â”œâ”€â”€ lambda_sns.tf           # Defines Serverless functions and SNS topics
â”‚       â”œâ”€â”€ iam.tf                  # Defines Permissions and Roles
â”‚       â”œâ”€â”€ security_groups.tf      # Defines Network Firewalls (SGs)
â”‚       â”œâ”€â”€ null_resources.tf       # Defines local compilation scripts (npm build)
â”‚       â”œâ”€â”€ variables.tf            # Defines inputs the module accepts (e.g., instance_type)
â”‚       â””â”€â”€ outputs.tf              # Defines what the module returns to the root
â”‚
â”œâ”€â”€ main.tf                         # Phase 3: Root Execution. Calls the `smartgrid-core` module
â”œâ”€â”€ providers.tf                    # Configures the AWS Provider and S3 Remote Backend link
â”œâ”€â”€ outputs.tf                      # Exposes the CloudFront URL to the user terminal
â”œâ”€â”€ variables.tf                    # Defines global variables (like AWS Region)
â””â”€â”€ .terraform.lock.hcl             # Lock file for the main application dependencies
```

---

## âš™ï¸  2. Core Terraform Concepts Explained

### Providers & Plugins
Terraform itself doesn't know how to talk to AWS. It relies on **Providers** (plugins). In `providers.tf`, we tell Terraform to download the `hashicorp/aws` provider. This provider translates our HCL (HashiCorp Configuration Language) code into actual AWS API calls.

### The Dependency Lock (`.terraform.lock.hcl`)
When you run `terraform init`, Terraform looks at the providers you requested and downloads them. It then records the *exact* version and a cryptographic hash of that plugin inside `.terraform.lock.hcl`. 
* **Why?** If another developer clones the repo a year from now, Terraform will download the exact same provider version listed in the lock file, guaranteeing the infrastructure deploys exactly the same way without unexpected breaking changes from AWS plugin updates.

### Variables (`variables.tf`) & Dynamic Parameterization
Instead of hardcoding values like `"t2.micro"`, we use variables. The `smartgrid-core` module exposes variables like `var.instance_type`. The root `main.tf` passes specific values into those variables, allowing us to build different shapes of the same architecture.

---

## ðŸŒ  3. State, Remote Backends, and DynamoDB Locking

Terraform needs to remember what it built. It stores this memory in a JSON file called **State** (`terraform.tfstate`). 

* **The Problem:** If the state file is stored locally on your laptop, another developer cannot safely modify the infrastructure, because their Terraform doesn't know what *your* Terraform already built.
* **The Solution (Remote Backend):** We use the `/backend-setup` directory to create a central AWS S3 Bucket. In `providers.tf`, we configure the `backend "s3"` block. Now, Terraform reads and writes the state directly to the cloud S3 bucket.
* **DynamoDB Locking:** If two developers run `terraform apply` at the exact same millisecond, the state file could corrupt. To prevent this, Terraform places a "lock" in a DynamoDB table while running. The second developer's terminal will simply pause and say "Waiting for state lock" until the first developer finishes.

---

## ðŸ”— 4. Environments & Workspaces

Workspaces allow you to use a **single folder of Terraform code** to manage **multiple isolated environments** (e.g., `dev`, `staging`, `prod`).

Instead of duplicating our code into two folders, we run:
```bash
terraform workspace new dev
terraform workspace new prod
```

When you switch to a workspace (`terraform workspace select dev`), Terraform looks at a separate, isolated state file in the S3 bucket (`env:/dev/terraform.tfstate`). 

### How `main.tf` Maps Workspaces Dynamically
In our root `main.tf`, we use the built-in `terraform.workspace` variable to dynamically change the infrastructure size depending on the environment:

```hcl
module "smartgrid_core" {
  source = "./modules/smartgrid-core"

  # If we are in "prod", use t2.medium. Otherwise, use t2.micro for dev.
  instance_type     = terraform.workspace == "prod" ? "t2.medium" : "t2.micro"
  
  # Prod gets 2 EC2 instances minimum. Dev only gets 1 to save money.
  asg_min_size      = terraform.workspace == "prod" ? 2 : 1
  
  # Prod gets the 10.0.0.0/16 network. Dev gets 10.1.0.0/16 to prevent collisions.
  vpc_cidr          = terraform.workspace == "prod" ? "10.0.0.0/16" : "10.1.0.0/16"
}
```
Furthermore, inside the `smartgrid-core` module, every single resource name is prefixed dynamically:
```hcl
name = "smartgrid-${var.environment}-vpc"
```
This ensures that the `dev` VPC and the `prod` VPC have completely different names in the AWS Console, preventing any naming conflicts!

---

## â–¶ï¸  5. The Complete Workflow (Step-by-Step)

If you were to start from an entirely new computer tomorrow, here is the exact flow of how everything maps together:

**Step 1: Clone the Repository**
You download the code from GitHub.

**Step 2: Initialize (`terraform init`)**
You navigate to the `terraform/` directory and run `terraform init`. 
* **What happens:** Terraform reads `providers.tf`, detects the S3 backend, downloads the AWS plugins based on `.terraform.lock.hcl`, and connects your local terminal to the remote S3 state bucket.

**Step 3: Select Workspace (`terraform workspace select dev`)**
* **What happens:** Terraform switches its context. It will now read the `dev` state file from S3, and the `terraform.workspace` variable internally evaluates to `"dev"`.

**Step 4: Plan (`terraform plan`)**
* **What happens:** Terraform compares the real world (AWS) against the state file (S3) against your code (`modules/smartgrid-core`). It generates an execution plan showing exactly what will be created, modified, or destroyed.

**Step 5: Execute (`terraform apply`)**
* **What happens:** 
  1. Terraform acquires a lock in DynamoDB.
  2. It builds the network (VPC, subnets) via `vpc.tf`.
  3. It builds the database via `rds.tf`.
  4. It invokes `null_resources.tf` to compile your local React code (`npm run build`) and uploads it to S3.
  5. It boots the EC2 servers via `instances.tf`. The servers run `user_data.sh` to download Node.js, clone your code, run DB migrations, and start the PM2 API.
  6. It outputs the `cloudfront_url` to your terminal via `outputs.tf`.
  7. It saves the new state back to the S3 bucket and releases the DynamoDB lock.

You can now click the CloudFront link and access your fully provisioned environment!
