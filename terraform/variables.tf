variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "eks_alb_dns" {
  type        = string
  description = "DNS hostname of the ALB created by the EKS Load Balancer Controller. Empty on first apply; set after Helm deploy to switch CloudFront to EKS."
  default     = ""
}
