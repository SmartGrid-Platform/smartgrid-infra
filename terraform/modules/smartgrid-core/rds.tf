#################################################
# RDS MySQL Database Configuration
#################################################

resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "smartgrid-${var.environment}-db-subnet-group"
  description = "Database subnet group for SmartGrid private DB subnets"
  subnet_ids  = [aws_subnet.private_db_a.id, aws_subnet.private_db_b.id]

  tags = {
    Name = "smartgrid-${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "database" {
  identifier             = "smartgrid-${var.environment}-rds-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 50
  storage_type           = "gp2"
  db_name                = "smartgrid"
  username               = "smartgrid_user"
  password               = "password" # Matches existing settings in services configs
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "smartgrid-${var.environment}-rds-mysql"
  }
}



