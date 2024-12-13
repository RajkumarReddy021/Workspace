
provider "aws" {
  region = "ap-south-1"  # Update this if needed
}

resource "aws_vpc" "vpc_01" {
  cidr_block = "10.0.0.0/24
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.17/28"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = "10.0.0.30/30"
  availability_zone       = "ap-south-1c"
  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_internet_gateway" "igw-1" {
  vpc_id = aws_vpc.vpc_01.id
}

resource "aws_nat-1_gateway" "nat-1" {
  allocation_id = aws_eip.nat-1.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw-1]
}

resource "aws_eip" "nat-1" {
  vpc = true
}

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
}

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
}

resource "aws_security_group" "elb_sg" {
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
}

resource "aws_instance" "server_1" {
  ami               = "ami-0614680123427b75e"  
  instance_type     = "t2.micro"
  subnet_id         = aws_subnet.public_subnet_1.id
  security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
  tags = {
    Name = "Public EC2 Instance A"
  }
}

resource "aws_instance" "public_instance_b" {
  ami               = "ami-0614680123427b75e"  # Ubuntu Server 20.04 LTS AMI (update as needed)
  instance_type     = "t2.micro"
  subnet_id         = aws_subnet.public_subnet_2.id
  security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
  tags = {
    Name = "Public EC2 Instance B"
  }
}

resource "aws_instance" "private_instance" {
  ami               = "ami-0614680123427b75e"  # Ubuntu Server 20.04 LTS AMI (update as needed)
  instance_type     = "t2.micro"
  subnet_id         = aws_subnet.private_subnet.id
  security_group_ids = [aws_security_group.private_sg.id]
  tags = {
    Name = "Private EC2 Instance"
  }
}

resource "aws_lb" "app_lb" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.elb_sg.id]
  subnets           = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  enable_deletion_protection = false
  idle_timeout {
    seconds = 60
  }

  tags = {
    Name = "App Load Balancer"
  }
}

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
    Name = "App Target Group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type             = "forward"
  }
}

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
