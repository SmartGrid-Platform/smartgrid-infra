#################################################
# Application Load Balancer & Routing
#################################################

# 1. External ALB Security Group (Public Web Access)
resource "aws_security_group" "alb_sg" {
  name        = "smartgrid-${var.environment}-alb-sg"
  description = "Allows public HTTP traffic to the ALB"
  vpc_id      = aws_vpc.smartgrid_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "smartgrid-${var.environment}-alb-sg"
  }
}

# 2. External Application Load Balancer (Public)
resource "aws_lb" "external_alb" {
  name               = "smartgrid-${var.environment}-external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "smartgrid-${var.environment}-external-alb"
  }
}

#################################################
# Target Groups (Dynamic ASG Targets)
#################################################

resource "aws_lb_target_group" "tg_auth" {
  name     = "tg-auth"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tg_consumer" {
  name     = "tg-consumer"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tg_meter" {
  name     = "tg-meter"
  port     = 3003
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tg_billing" {
  name     = "tg-billing"
  port     = 3004
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tg_alert" {
  name     = "tg-alert"
  port     = 3005
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tg_assistant" {
  name     = "tg-assistant"
  port     = 4004
  protocol = "HTTP"
  vpc_id   = aws_vpc.smartgrid_vpc.id

  health_check {
    path                = "/api/assistant/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#################################################
# Listener & Rules
# (Receives forwarded API requests from CloudFront)
#################################################

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "route_auth" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_auth.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth*"]
    }
  }
}

resource "aws_lb_listener_rule" "route_consumer" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_consumer.arn
  }

  condition {
    path_pattern {
      values = ["/api/consumers*"]
    }
  }
}

resource "aws_lb_listener_rule" "route_meter" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_meter.arn
  }

  condition {
    path_pattern {
      values = ["/api/meters*"]
    }
  }
}

resource "aws_lb_listener_rule" "route_billing" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_billing.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/bills*",
        "/api/tariffs*",
        "/api/recharges*"
      ]
    }
  }
}

resource "aws_lb_listener_rule" "route_alert" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_alert.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/alerts*",
        "/api/inspections*"
      ]
    }
  }
}

resource "aws_lb_listener_rule" "route_assistant" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 60

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_assistant.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/assistant*"
      ]
    }
  }
}


