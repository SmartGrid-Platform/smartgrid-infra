# SmartGrid — Repository Split Plan

**Status:** Phase 1 Analysis Complete — DO NOT execute split until Phase 4.
**Branch:** eksmigration
**Date:** 2026-06-23

---

## 1. Target Repository Structure

The monorepo splits into three purpose-built repositories:

```
smartgrid-infra     Infrastructure-as-code, cluster bootstrap
smartgrid-helm      Helm chart, ArgoCD application templates
smartgrid-apps      Application source code, Dockerfiles, CI
```

---

## 2. File Ownership Mapping

### smartgrid-infra

| Source Path | Destination |
|---|---|
| `terraform/` | `terraform/` |
| `terraform/backend-setup/` | `terraform/backend-setup/` |
| `lambdas/` | `lambdas/` |
| `argocd/` | `argocd/` |
| `.github/workflows/infra.yml` | `.github/workflows/infra.yml` |
| `.github/workflows/bootstrap.yml` | `.github/workflows/bootstrap.yml` |
| `docs/PROJECT_ARCHITECTURE.md` | `docs/PROJECT_ARCHITECTURE.md` |

Default branch: `main`

### smartgrid-helm

| Source Path | Destination |
|---|---|
| `helm/smartgrid/` | `helm/smartgrid/` |
| `argocd/application.yaml` | `argocd/application.yaml` |
| `argocd/application-prod.yaml` | `argocd/application-prod.yaml` |

Branches required: `dev` (auto-sync), `prod` (manual-sync)
ArgoCD watches path `helm/smartgrid` on both branches.

### smartgrid-apps

| Source Path | Destination |
|---|---|
| `services/` | `services/` |
| `frontend/` | `frontend/` |
| `shared/` | `shared/` |
| `docker-compose.yml` | `docker-compose.yml` |
| `.github/workflows/main.yml` | `.github/workflows/main.yml` |
| `.github/workflows/ci-template.yml` | `.github/workflows/ci-template.yml` |
| `.github/workflows/ci-auth-service.yml` | `.github/workflows/ci-auth-service.yml` |
| `.github/workflows/ci-consumer-service.yml` | `.github/workflows/ci-consumer-service.yml` |
| `.github/workflows/ci-meter-service.yml` | `.github/workflows/ci-meter-service.yml` |
| `.github/workflows/ci-billing-service.yml` | `.github/workflows/ci-billing-service.yml` |
| `.github/workflows/ci-alert-service.yml` | `.github/workflows/ci-alert-service.yml` |
| `.github/workflows/ci-ai-assistant-service.yml` | `.github/workflows/ci-ai-assistant-service.yml` |
| `.github/workflows/notify-failure.yml` | `.github/workflows/notify-failure.yml` |
| `.github/workflows/deploy-eks.yml` | `.github/workflows/deploy-eks.yml` |

Default branch: `dev` (CI triggers on dev)

---

## 3. Cross-Repository Dependency Map

```
smartgrid-infra
  ├── creates: VPC, EKS, RDS, ECR, Secrets Manager, Lambda, SQS, SNS, CloudFront
  ├── writes:  Terraform state → S3 backend (TF_STATE_BUCKET)
  └── no dependency on smartgrid-apps or smartgrid-helm

smartgrid-apps  (reads TF state; writes to smartgrid-helm)
  ├── reads:   terraform outputs via S3 remote state (read-only)
  │            → cluster_name, k8s_namespace, ecr_registry_url,
  │              eks_pod_role_arn, secrets_manager_secret_name
  ├── writes:  imageTag to smartgrid-helm/helm/smartgrid/values.yaml (dev branch)
  │            via GH_PAT in main.yml update-helm-values job
  └── no dependency on smartgrid-infra source code

smartgrid-helm  (no outbound code dependencies)
  ├── ArgoCD watches: this repo's dev and prod branches
  ├── references: smartgrid-infra outputs (injected at bootstrap time, not at build time)
  └── receives: imageTag pushes from smartgrid-apps CI
```

**Circular dependency check: NONE** ✅

---

## 4. Required GitHub Variables Per Repository

### smartgrid-infra

| Variable | Example Value | Required |
|---|---|---|
| `TF_STATE_BUCKET` | `smartgrid-tf-state-06vasp` | ✅ |
| `TF_STATE_LOCK_TABLE` | `smartgrid-tf-locks-06vasp` | ✅ |
| `GITHUB_ORG` | `Likhi161` | ✅ |
| `ARGOCD_CHART_VERSION` | `7.7.3` | ✅ |
| `CLUSTER_AUTOSCALER_CHART_VER` | `9.43.2` | ✅ |
| `CLUSTER_AUTOSCALER_IMAGE_TAG` | `v1.31.0` | ✅ |
| `ARGOCD_NAMESPACE` | `argocd` | optional (default: `argocd`) |
| `LBC_CHART_VERSION` | `1.8.1` | optional (default: `1.8.1`) |

### smartgrid-apps

| Variable | Example Value | Required |
|---|---|---|
| `GITHUB_ORG` | `Likhi161` | ✅ |
| `TF_STATE_BUCKET` | `smartgrid-tf-state-06vasp` | ✅ |
| `TF_STATE_LOCK_TABLE` | `smartgrid-tf-locks-06vasp` | ✅ |
| `ECR_REPO_PREFIX` | `smartgrid-default` | ✅ (replaces hardcoded prefix in ci-template.yml) |

### smartgrid-helm

No variables required. ArgoCD polls via deploy key or GH_PAT.

---

## 5. Required GitHub Secrets Per Repository

### smartgrid-infra

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | Terraform and AWS CLI |
| `AWS_SECRET_ACCESS_KEY` | Terraform and AWS CLI |
| `AWS_REGION` | e.g. `ap-south-1` |
| `TF_VAR_db_password` | RDS master password |
| `TF_VAR_jwt_secret` | JWT signing secret |
| `TF_VAR_admin_password` | Bootstrap admin password |
| `TF_VAR_smtp_user` | SMTP username (optional) |
| `TF_VAR_smtp_pass` | SMTP password (optional) |
| `TF_VAR_notification_email` | SNS alert email (optional) |
| `GH_PAT` | Bootstrap uses for ArgoCD repo registration |

### smartgrid-apps

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | ECR login, read Secrets Manager, EKS access |
| `AWS_SECRET_ACCESS_KEY` | As above |
| `AWS_REGION` | e.g. `ap-south-1` |
| `GH_PAT` | Push imageTag commit to smartgrid-helm |
| `SONAR_TOKEN` | SonarCloud SAST (optional) |
| `SNYK_TOKEN` | Snyk dependency scan (optional) |

### smartgrid-helm

No secrets required for ArgoCD polling (uses deploy key configured in ArgoCD).

---

## 6. Branch Protection Strategy

### smartgrid-infra / main
- Require PR review before merge
- Require `terraform validate` status check to pass
- Restrict direct pushes to main
- No force pushes

### smartgrid-helm / dev
- Allow ArgoCD-triggered reads (no PR gate needed)
- CI bot (`ci@github.com`) may push imageTag updates without review
- Protect from force pushes

### smartgrid-helm / prod
- Require PR from dev with manual review
- ArgoCD sync is manual-only
- No direct pushes

### smartgrid-apps / dev
- CI triggers automatically on push
- Require status checks: all 6 service CIs must pass before helm update fires

### smartgrid-apps / main
- Require PR from dev
- Require all CI checks to pass
- No direct pushes

---

## 7. Files NOT to Migrate (Remove Before Split)

### `kubernetes/` — LEGACY (delete entirely)

Superseded by `helm/smartgrid/`. Contains hardcoded account IDs and
image references from before the EKS migration. Do not migrate to any repo.

### Root-level scratch and artifact files (gitignored in this commit)

These files are already excluded from future commits via `.gitignore` update:

```
logs.txt, logs2.txt, update_log.txt
console.json, response.json, lt_userdata.json, ssm_payload.json
query-db.js, query-meters.js, query-readings.js
scratch_test_bedrock.js, test-apis.js, test-e2e-queries.js
AWS_Services_Lambdas_Overview.txt, terraformflowguide.md
user_data_fixed.sh, kms_policy.json
```

These will be removed from git history during Phase 4 split (new repos start clean).

---

## 8. Workflow Reference Changes Required at Split Time (Phase 4)

### main.yml `update-helm-values` (no change needed)
Already uses `${{ vars.GITHUB_ORG }}/smartgrid-helm` — fully dynamic. ✅

### bootstrap.yml ArgoCD Application heredocs (no change needed)
Uses `${GITHUB_ORG}/smartgrid-helm.git` from env var at runtime. ✅

### argocd/application.yaml repoURL (no change needed)
Uses `${GITHUB_ORG}` placeholder — substituted at bootstrap time. ✅

### ci-template.yml `configure-aws-credentials` (FIXED in this commit)
Was `@v2` → now `@v4`. ECR prefix was hardcoded → now `vars.ECR_REPO_PREFIX`. ✅

### deploy-eks.yml post-split consideration
Currently runs `helm upgrade --install` directly from local `./helm/smartgrid`.
Post-split (smartgrid-apps repo), the chart is in smartgrid-helm, not co-located.
**Options:**
1. Check out smartgrid-helm in deploy-eks.yml (adds checkout step)
2. Rely entirely on ArgoCD sync — remove `deploy-eks.yml` and trigger
   `argocd app sync` instead (preferred; removes direct Helm deploy)
3. Keep Helm push in deploy-eks.yml and use `helm pull` from OCI registry

**Recommendation:** Option 2 — convert deploy-eks.yml into an ArgoCD sync trigger
post-split. The `read-tf-outputs` job still runs for image verification. ArgoCD
handles actual deployment. This eliminates the chart co-location requirement.

---

## 9. Pre-Split Verification Checklist

- [x] ci-template.yml hardcoded ECR prefix fixed (`ECR_REPO_PREFIX` variable)
- [x] ci-template.yml `configure-aws-credentials` upgraded to @v4
- [x] Scratch and artifact files added to .gitignore
- [x] No circular dependencies confirmed
- [x] Workflow cross-repo references documented
- [ ] `smartgrid-helm` GitHub repository exists with `dev` and `prod` branches
- [ ] `smartgrid-infra` GitHub repository exists
- [ ] `smartgrid-apps` GitHub repository exists
- [ ] ArgoCD deploy key or GH_PAT configured with read access to `smartgrid-helm`
- [ ] `ECR_REPO_PREFIX` variable added to `smartgrid-apps` Actions Variables
- [ ] `kubernetes/` directory removed (Phase 4)
- [ ] `terraform plan` succeeds against live backend (Phase 2)
