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

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
