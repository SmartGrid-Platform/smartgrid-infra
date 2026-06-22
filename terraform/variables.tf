variable "aws_region" {
  type        = string
  description = "AWS deployment region"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g. default, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for EKS node group"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
}

variable "asg_min_size" {
  type        = number
  description = "Minimum number of EKS nodes"
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of EKS nodes"
}

variable "eks_alb_dns" {
  type        = string
  description = "DNS hostname of the ALB created by the EKS Load Balancer Controller. Empty on first apply; set after Helm deploy to switch CloudFront to EKS."
}

variable "eks_node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS worker nodes (must be at least t3.small)"
}

variable "enable_guardduty" {
  type        = bool
  description = "Whether to enable GuardDuty. Set to false on new accounts without a payment method."
}

variable "enable_bastion" {
  type        = bool
  description = "Whether to create the bastion EC2 instance. Disable to save cost; use SSM Session Manager instead."
}

# ── Secrets (set via TF_VAR_* env vars — never in tfvars) ────────────
variable "db_password" {
  description = "RDS master password. Set via TF_VAR_db_password (GitHub Secret: TF_VAR_RDS_PASSWORD)."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret. Set via TF_VAR_jwt_secret (GitHub Secret: TF_VAR_JWT_SECRET)."
  type        = string
  sensitive   = true
}

variable "admin_name" {
  description = "Bootstrap admin display name."
  type        = string
  default     = "Admin"
}

variable "admin_email" {
  description = "Bootstrap admin email address."
  type        = string
  default     = "admin@smartgrid.com"
}

variable "admin_password" {
  description = "Bootstrap admin password. Set via TF_VAR_admin_password (GitHub Secret: TF_VAR_ADMIN_PASSWORD)."
  type        = string
  sensitive   = true
}

# ── Database config ────────────────────────────────────────────────
variable "db_name" {
  description = "RDS database schema name"
  type        = string
  default     = "smartgrid"
}

variable "db_user" {
  description = "RDS master username"
  type        = string
  default     = "smartgrid_user"
}

variable "db_port" {
  description = "RDS port number"
  type        = number
  default     = 3306
}

# ── Email (SMTP) ───────────────────────────────────────────────────
variable "smtp_host" {
  description = "SMTP relay hostname for outgoing email. Leave empty to disable."
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP relay port"
  type        = string
  default     = ""
}

variable "smtp_user" {
  description = "SMTP authentication username. Set via TF_VAR_smtp_user (GitHub Secret: TF_VAR_SMTP_USER)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_pass" {
  description = "SMTP authentication password. Set via TF_VAR_smtp_pass (GitHub Secret: TF_VAR_SMTP_PASS)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sender_email" {
  description = "From address for application-generated emails"
  type        = string
  default     = ""
}

# ── AI / Bedrock ───────────────────────────────────────────────────
variable "bedrock_primary_model" {
  description = "AWS Bedrock primary model ID for the AI assistant"
  type        = string
  default     = "us.amazon.nova-pro-v1:0"
}

variable "bedrock_fallback_model" {
  description = "AWS Bedrock fallback model ID (cheaper, used when primary is throttled)"
  type        = string
  default     = "us.amazon.nova-lite-v1:0"
}

# ── Kubernetes ─────────────────────────────────────────────────────
variable "k8s_namespace" {
  description = "Kubernetes namespace for SmartGrid services. Must match the IRSA trust policy."
  type        = string
  default     = "production"
}

# ── Notifications ──────────────────────────────────────────────────
variable "notification_email" {
  description = "Email address to receive SNS alert notifications (low-balance, disconnection)."
  type        = string
  default     = ""
}
