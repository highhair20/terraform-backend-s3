provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.role_arn
  }
}

resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = var.project_name
  }
}

resource "aws_security_group" "this" {
  name        = var.project_name
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.30.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.20.40.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

data "aws_ami" "selected" {
  owners = ["amazon"]

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "description"
    values = ["Amazon Linux 20*"]
  }

  filter {
    name   = "boot-mode"
    values = ["uefi-preferred"]
  }

  most_recent = true
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.selected.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = aws_subnet.public.id

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo dnf install -y httpd
    echo "<h1>${var.project_name}</h1><h3>Hello, World!</h3>" > /var/www/html/index.html
    sudo systemctl enable httpd
    sudo systemctl start httpd
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = var.project_name
  }
}
