#################################################
# Remote State — S3 Backend
#
# Prerequisites (one-time setup):
#   cd terraform/backend-setup
#   terraform init && terraform apply
#   # Note the output values: state_bucket_name, dynamodb_table_name
#
# Then add these GitHub repository variables:
#   TF_STATE_BUCKET     = <state_bucket_name output>
#   TF_STATE_LOCK_TABLE = <dynamodb_table_name output>
#
# The bucket name and lock table name are NOT hardcoded here because
# they are created with a random suffix by backend-setup/main.tf.
# Terraform reads -backend-config values from the CI workflow.
#################################################
terraform {
  backend "s3" {
    key     = "smartgrid/terraform.tfstate"
    encrypt = true
    # bucket, region, and dynamodb_table are passed via -backend-config
    # in infra.yml and bootstrap.yml — never hardcode them here.
  }
}
