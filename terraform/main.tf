module "smartgrid_core" {
  source = "./modules/smartgrid-core"

  environment       = terraform.workspace
  aws_region        = var.aws_region
  instance_type     = terraform.workspace == "prod" ? "t2.medium" : "t2.micro"
  db_instance_class = terraform.workspace == "prod" ? "db.t3.medium" : "db.t3.micro"
  asg_min_size      = terraform.workspace == "prod" ? 2 : 1
  asg_max_size      = terraform.workspace == "prod" ? 4 : 2
  vpc_cidr          = terraform.workspace == "prod" ? "10.0.0.0/16" : "10.1.0.0/16"
  eks_alb_dns       = var.eks_alb_dns

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
