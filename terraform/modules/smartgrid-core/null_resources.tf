#################################################
# Local Compilation & S3 Upload Automation
#################################################

resource "null_resource" "upload_frontend" {
  depends_on = [aws_s3_bucket.frontend_bucket]

  triggers = {
    always_run = timestamp()
  }

  # Builds the React app and uploads to S3 in one step.
  # Requires Node.js (npm) on the machine running terraform apply.
  # If npm is not installed, this step is skipped gracefully so the rest
  # of the infrastructure is still created. Upload the frontend manually:
  #   cd frontend && npm install && npm run build
  #   aws s3 sync dist s3://<frontend-bucket> --delete
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      if ! command -v npm &>/dev/null; then
        echo "WARNING: npm not found — skipping frontend build. Upload manually after installing Node.js."
        exit 0
      fi
      cd "${path.root}/../frontend"
      npm install || exit 1
      npm run build || exit 1
      aws s3 sync dist "s3://${aws_s3_bucket.frontend_bucket.id}" --delete
    EOT
  }
}



