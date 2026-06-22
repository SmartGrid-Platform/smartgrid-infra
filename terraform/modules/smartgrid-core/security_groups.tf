#################################################
# Security Groups
#################################################

# Bastion SG — SSH removed; access via SSM Session Manager (no open port needed)
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.smartgrid_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Backend SG (For ASG Backend Instances)
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = aws_vpc.smartgrid_vpc.id

  # Allow SSH from Bastion Host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow API traffic on microservices ports from public ALB SG
  ingress {
    from_port       = 3001
    to_port         = 3005
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow AI Assistant traffic from public ALB SG
  ingress {
    from_port       = 4004
    to_port         = 4004
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# Database SG (For RDS Instance)
resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.smartgrid_vpc.id

  # Allow MySQL connections from backend microservices and EKS pods
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [
      aws_security_group.backend_sg.id,
      aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}


