module "smartgrid_core" {
  source = "./modules/smartgrid-core"

  environment            = var.environment
  aws_region             = var.aws_region
  vpc_cidr               = var.vpc_cidr
  instance_type          = var.instance_type
  db_instance_class      = var.db_instance_class
  asg_min_size           = var.asg_min_size
  asg_max_size           = var.asg_max_size
  eks_alb_dns            = var.eks_alb_dns
  eks_node_instance_type = var.eks_node_instance_type
  enable_guardduty       = var.enable_guardduty
  enable_bastion         = var.enable_bastion
  db_password            = var.db_password
  jwt_secret             = var.jwt_secret
  admin_name             = var.admin_name
  admin_email            = var.admin_email
  admin_password         = var.admin_password
  db_name                = var.db_name
  db_user                = var.db_user
  db_port                = var.db_port
  smtp_host              = var.smtp_host
  smtp_port              = var.smtp_port
  smtp_user              = var.smtp_user
  smtp_pass              = var.smtp_pass
  sender_email           = var.sender_email
  bedrock_primary_model  = var.bedrock_primary_model
  bedrock_fallback_model = var.bedrock_fallback_model
  k8s_namespace          = var.k8s_namespace
  notification_email     = var.notification_email

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
