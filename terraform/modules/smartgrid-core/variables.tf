variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
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
