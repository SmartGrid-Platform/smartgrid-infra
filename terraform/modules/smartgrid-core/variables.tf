variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "The EC2 instance type for the backend ASG"
  type        = string
  default     = "t2.micro"
}

variable "db_instance_class" {
  description = "The RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "asg_min_size" {
  description = "Minimum size of the backend Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the backend Auto Scaling Group"
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_alb_dns" {
  description = "DNS hostname of the ALB created by the EKS Load Balancer Controller. Empty on first apply; set after Helm deploy to switch CloudFront to EKS."
  type        = string
  default     = ""
}


