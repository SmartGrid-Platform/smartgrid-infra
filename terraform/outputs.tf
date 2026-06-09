output "cloudfront_url" {
  value       = module.smartgrid_core.cloudfront_domain_name
  description = "The CloudFront Distribution Domain Name"
}

output "alb_dns" {
  value       = module.smartgrid_core.external_alb_dns_name
  description = "The Application Load Balancer DNS Name"
}
