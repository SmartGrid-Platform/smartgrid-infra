#################################################
# Outputs
#################################################

output "vpc_id" {
  value       = aws_vpc.smartgrid_vpc.id
  description = "The ID of the VPC"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion Host"
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


