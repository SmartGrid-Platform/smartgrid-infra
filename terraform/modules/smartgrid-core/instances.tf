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




