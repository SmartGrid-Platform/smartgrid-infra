aws_region             = "ap-south-1"
environment            = "default"
vpc_cidr               = "10.0.0.0/16"
instance_type          = "t2.micro"
eks_node_instance_type = "t3.medium"
db_instance_class      = "db.t3.micro"
asg_min_size           = 2
asg_max_size           = 4
eks_alb_dns            = ""
enable_guardduty       = false
enable_bastion         = false

# Non-sensitive admin metadata (safe to commit)
admin_name  = "Admin"
admin_email = "admin@smartgrid.com"

# SENSITIVE VARIABLES — do NOT add here.
# Set these as GitHub Organization Secrets and map them in the CI workflow:
#   TF_VAR_RDS_PASSWORD   → db_password
#   TF_VAR_JWT_SECRET     → jwt_secret
#   TF_VAR_ADMIN_PASSWORD → admin_password
