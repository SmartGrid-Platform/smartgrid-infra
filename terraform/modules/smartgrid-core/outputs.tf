#################################################
# Outputs
#################################################

output "vpc_id" {
  value       = aws_vpc.smartgrid_vpc.id
  description = "The ID of the VPC"
}

output "bastion_public_ip" {
  value       = length(aws_instance.bastion) > 0 ? aws_instance.bastion[0].public_ip : ""
  description = "Public IP address of the Bastion Host (empty when enable_bastion = false)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "The domain name of the CloudFront distribution serving the React app"
}

output "rds_endpoint" {
  value       = aws_db_instance.database.endpoint
  description = "The connection endpoint for the RDS MySQL instance"
}

output "external_alb_dns_name" {
  value       = aws_lb.external_alb.dns_name
  description = "The DNS name of the External Application Load Balancer"
}

output "eks_cluster_name" {
  value       = aws_eks_cluster.eks.name
  description = "The EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.eks.endpoint
  description = "The EKS cluster endpoint"
}

output "eks_cluster_certificate_authority_data" {
  value       = aws_eks_cluster.eks.certificate_authority[0].data
  description = "The EKS cluster certificate authority data"
}

output "eks_pod_role_arn" {
  value       = aws_iam_role.eks_pod_role.arn
  description = "The ARN of the EKS Pod IAM role"
}

output "ecr_registry_url" {
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  description = "The URL of the AWS ECR registry"
}

output "lbc_role_arn" {
  value       = aws_iam_role.aws_load_balancer_controller.arn
  description = "IAM Role ARN for the AWS Load Balancer Controller (IRSA)"
}

output "autoscaler_role_arn" {
  value       = aws_iam_role.cluster_autoscaler.arn
  description = "IAM Role ARN for the Cluster Autoscaler (IRSA)"
}

output "secrets_manager_secret_name" {
  value       = aws_secretsmanager_secret.smartgrid_secret.name
  description = "Name of the Secrets Manager secret containing all runtime config"
}
