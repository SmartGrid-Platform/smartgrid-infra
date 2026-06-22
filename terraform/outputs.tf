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

output "cluster_name" {
  value       = module.smartgrid_core.eks_cluster_name
  description = "Alias for eks_cluster_name — used by bootstrap.yml"
}

output "eks_cluster_endpoint" {
  value       = module.smartgrid_core.eks_cluster_endpoint
  description = "The EKS cluster endpoint"
}

output "ecr_registry_url" {
  value       = module.smartgrid_core.ecr_registry_url
  description = "The URL of the AWS ECR registry"
}

output "rds_endpoint" {
  value       = module.smartgrid_core.rds_endpoint
  description = "The connection endpoint for the RDS MySQL instance"
}

output "eks_pod_role_arn" {
  value       = module.smartgrid_core.eks_pod_role_arn
  description = "IAM Role ARN for EKS pods (IRSA) — injected into Helm serviceAccount"
}

output "lbc_role_arn" {
  value       = module.smartgrid_core.lbc_role_arn
  description = "IAM Role ARN for the AWS Load Balancer Controller (IRSA)"
}

output "autoscaler_role_arn" {
  value       = module.smartgrid_core.autoscaler_role_arn
  description = "IAM Role ARN for the Cluster Autoscaler (IRSA)"
}

output "secrets_manager_secret_name" {
  value       = module.smartgrid_core.secrets_manager_secret_name
  description = "Name of the Secrets Manager secret containing all runtime config"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region where the stack is deployed"
}

output "k8s_namespace" {
  value       = module.smartgrid_core.k8s_namespace
  description = "Kubernetes namespace for SmartGrid services"
}
