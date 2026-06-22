#################################################
# VPC
#################################################

resource "aws_vpc" "smartgrid_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                                                     = "smartgrid-${var.environment}-vpc"
    "kubernetes.io/cluster/smartgrid-${var.environment}-cluster" = "shared"
  }
}

#################################################
# Availability Zones
#################################################

data "aws_availability_zones" "available" {}

#################################################
# Subnets
#################################################

# Public A
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.smartgrid_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                                     = "public-subnet-a"
    "kubernetes.io/role/elb"                                 = "1"
    "kubernetes.io/cluster/smartgrid-${var.environment}-cluster" = "shared"
  }
}

# Public B
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.smartgrid_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                                                     = "public-subnet-b"
    "kubernetes.io/role/elb"                                 = "1"
    "kubernetes.io/cluster/smartgrid-${var.environment}-cluster" = "shared"
  }
}

# Private App A
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.smartgrid_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                                                     = "private-app-a"
    "kubernetes.io/role/internal-elb"                        = "1"
    "kubernetes.io/cluster/smartgrid-${var.environment}-cluster" = "shared"
  }
}

# Private App B
resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.smartgrid_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                                                     = "private-app-b"
    "kubernetes.io/role/internal-elb"                        = "1"
    "kubernetes.io/cluster/smartgrid-${var.environment}-cluster" = "shared"
  }
}

# Private DB A
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.smartgrid_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 21)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "private-db-a"
  }
}

# Private DB B
resource "aws_subnet" "private_db_b" {
  vpc_id            = aws_vpc.smartgrid_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 22)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "private-db-b"
  }
}

#################################################
# Internet Gateway
#################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.smartgrid_vpc.id

  tags = {
    Name = "smartgrid-${var.environment}-igw"
  }
}

#################################################
# NAT Gateway — single NAT (cost-efficient for demo environment)
#################################################

resource "aws_eip" "nat_eip_a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "smartgrid-${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

#################################################
# Route Tables
#################################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.smartgrid_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Single private route table — both AZs route through the one NAT
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.smartgrid_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "smartgrid-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.smartgrid_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.db_rt.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.private_db_b.id
  route_table_id = aws_route_table.db_rt.id
}

#################################################
# VPC Flow Logs — network-level audit trail
#################################################

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/smartgrid-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "smartgrid-${var.environment}-vpc-flow-logs"
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "smartgrid-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-write"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.smartgrid_vpc.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name        = "smartgrid-${var.environment}-vpc-flow-log"
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}




