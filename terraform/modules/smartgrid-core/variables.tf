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
