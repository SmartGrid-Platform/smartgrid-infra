variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
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

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type for EKS nodes"
  type        = string
}

variable "db_instance_class" {
  description = "The RDS instance class"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum size of the EKS node group"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum size of the EKS node group"
  type        = number
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "eks_alb_dns" {
  description = "DNS hostname of the ALB created by the EKS Load Balancer Controller. Empty on first apply; set after Helm deploy to switch CloudFront to EKS."
  type        = string
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes (must be at least t3.small — t2.micro is too small for EKS)"
  type        = string
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty. Set to false on new accounts without a payment method."
  type        = bool
}

variable "enable_bastion" {
  description = "Whether to create the bastion EC2 instance. Disable to save cost; use SSM Session Manager instead."
  type        = bool
}
