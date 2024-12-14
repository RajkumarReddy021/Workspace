# VPC creation
resource "aws_vpc" "vpc_01" {
  cidr_block = "10.0.0.0/24"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Demovpc"
  }
}

# Public Subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.0/28"  # Provides 16 IPs, 14 usable
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 1"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.16/28"  # Provides 16 IPs, 14 usable
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 2"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.32/28"  # Provides 16 IPs, 14 usable
  availability_zone       = "ap-south-1b"

  tags = {
    Name = "Private Subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_01.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_1" {
  domain = "vpc"  # Deprecated vpc = true updated
}

# NAT Gateway in Public Subnet 1
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  depends_on = [aws_internet_gateway.igw_1]
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_01.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Private Route Table Association
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for Public Instances
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.vpc_01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-1"
  }
}

# Security Group for Private Instances
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.vpc_01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow traffic from VPC
  }

  tags = {
    Name = "sg-2"
  }
}

# EC2 Instance 1 (Public Subnet 1)
resource "aws_instance" "server_1" {
  ami                    = "ami-0614680123427b75e"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  security_groups        = [aws_security_group.public_sg.id]  # Use .id instead of .name
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1> $(hostname) </h1>" > /var/www/html/index.html
              EOF
  tags = {
    Name = "server-1"
  }
}

# EC2 Instance 2 (Public Subnet 2)
resource "aws_instance" "public_instance_b" {
  ami                    = "ami-0614680123427b75e"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  security_groups        = [aws_security_group.public_sg.id]  # Use .id instead of .name
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
  tags = {
    Name = "server-2"
  }
}

# EC2 Instance 3 (Private Subnet)
resource "aws_instance" "private_instance" {
  ami                    = "ami-0614680123427b75e"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.private_subnet.id
  availability_zone      = "ap-south-1b"
  security_groups        = [aws_security_group.private_sg.id]
  tags = {
    Name = "server-3(Private)"
  }
}


# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  enable_deletion_protection = false
  idle_timeout       = 60

  tags = {
    Name = "Load Balancer-1"
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "target_group" {
  name     = "tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_01.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "Target Group-1"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type             = "forward"
  }
}

# Attach EC2 Instances to Target Group
resource "aws_lb_target_group_attachment" "attachment_public_a" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = aws_instance.server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachment_public_b" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = aws_instance.public_instance_b.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachment_private" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = aws_instance.private_instance.id
  port             = 80
}
