#################################################
# EC2 Bastion & Auto Scaling Group
#################################################

# 1. Bastion Host (Public Access for maintenance)
resource "aws_instance" "bastion" {
  ami                         = "ami-07a00cf47dbbc844c"
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = "Likhitha-pem"

  tags = {
    Name = "smartgrid-${var.environment}-bastion"
  }
}

# 2. Launch Template for Backend Microservices
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "smartgrid-${var.environment}-backend-lt-"
  image_id      = "ami-07a00cf47dbbc844c"
  instance_type = var.instance_type
  key_name      = "Likhitha-pem"

  iam_instance_profile {
    name = aws_iam_instance_profile.backend_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.backend_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_host              = aws_db_instance.database.address
    db_name              = aws_db_instance.database.db_name
    db_user              = aws_db_instance.database.username
    db_password          = aws_db_instance.database.password
    aws_region           = var.aws_region
    secret_name          = aws_secretsmanager_secret.smartgrid_secret.name
    lambda_bill_generator = module.lambda_bill_generator.lambda_function_name
    lambda_tariff_engine  = module.lambda_tariff_engine.lambda_function_name
    lambda_unit_calculator = module.lambda_unit_calculator.lambda_function_name
    s3_bucket_name        = aws_s3_bucket.bills_bucket.id
  }))

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "smartgrid-${var.environment}-backend"
    }
  }
}

# 3. Auto Scaling Group in Private App Subnets
resource "aws_autoscaling_group" "backend_asg" {
  name_prefix         = "smartgrid-${var.environment}-backend-asg-"
  vpc_zone_identifier = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_min_size

  target_group_arns = [
    aws_lb_target_group.tg_auth.arn,
    aws_lb_target_group.tg_consumer.arn,
    aws_lb_target_group.tg_meter.arn,
    aws_lb_target_group.tg_billing.arn,
    aws_lb_target_group.tg_alert.arn,
    aws_lb_target_group.tg_assistant.arn
  ]

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true

  tag {
    key                 = "Name"
    value               = "smartgrid-${var.environment}-backend-asg-node"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}



