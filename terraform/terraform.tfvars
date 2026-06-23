aws_region             = "ap-south-1"
environment            = "default"
vpc_cidr               = "10.0.0.0/16"
instance_type          = "t2.micro"
eks_node_instance_type = "t3.small"
db_instance_class      = "db.t3.micro"
asg_min_size           = 1
asg_max_size           = 1
eks_alb_dns            = ""
enable_guardduty       = false
enable_bastion         = false

# ── Override defaults here as needed ──────────────────────────────
# All variables below have sensible defaults in variables.tf.
# Uncomment and set only if you need to deviate from defaults.
#
# db_name               = "smartgrid"
# db_user               = "smartgrid_user"
# db_port               = 3306
# k8s_namespace         = "production"
# bedrock_primary_model = "us.amazon.nova-pro-v1:0"
# bedrock_fallback_model = "us.amazon.nova-lite-v1:0"
# smtp_host             = ""
# smtp_port             = ""
# sender_email          = ""
# admin_name            = "Admin"
# admin_email           = "admin@smartgrid.com"

# ── SENSITIVE VARIABLES — NEVER add here ──────────────────────────
# Set as GitHub Organization Secrets and map via TF_VAR_* in infra.yml:
#   TF_VAR_RDS_PASSWORD   → db_password
#   TF_VAR_JWT_SECRET     → jwt_secret
#   TF_VAR_ADMIN_PASSWORD → admin_password
#   TF_VAR_SMTP_USER      → smtp_user      (optional)
#   TF_VAR_SMTP_PASS      → smtp_pass      (optional)
