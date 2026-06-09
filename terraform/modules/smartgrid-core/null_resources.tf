#################################################
# Local Compilation & S3 Upload Automation
#################################################

resource "null_resource" "build_frontend" {
  triggers = {
    # Force build on every apply to ensure code is synchronized
    always_run = timestamp()
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/../frontend"
    command     = "npm install && npm run build"
  }
}

resource "null_resource" "upload_frontend" {
  depends_on = [
    null_resource.build_frontend,
    aws_s3_bucket.frontend_bucket
  ]

  triggers = {
    # Force upload when build finishes
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "aws s3 sync ${path.root}/../frontend/dist s3://${aws_s3_bucket.frontend_bucket.id} --delete"
  }
}



