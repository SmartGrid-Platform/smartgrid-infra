output "cloudfront_url" {
  value       = module.smartgrid_core.cloudfront_domain_name
  description = "The CloudFront Distribution Domain Name"
}

output "alb_dns" {
  value       = module.smartgrid_core.external_alb_dns_name
  description = "The Application Load Balancer DNS Name"
}

output "eks_cluster_name" {
  value       = module.smartgrid_core.eks_cluster_name
  description = "The EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = module.smartgrid_core.eks_cluster_endpoint
  description = "The EKS cluster endpoint"
}

output "ecr_registry_url" {
  value       = module.smartgrid_core.ecr_registry_url
  description = "The URL of the AWS ECR registry"
}


