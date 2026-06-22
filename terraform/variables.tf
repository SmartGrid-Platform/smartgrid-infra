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
