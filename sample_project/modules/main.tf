provider "aws" {
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

resource "aws_vpc" "this" {
 cidr_block = "10.20.0.0/16"
 instance_tenancy = "default"
 enable_dns_hostnames = "true"

 tags = {
  Name = "${var.project_name}"
 }
}

resource "aws_security_group" "this" {
 name = "${var.project_name}"
 description = "This firewall allows SSH, HTTP"
 vpc_id = "${aws_vpc.this.id}"

 ingress {
  description = "SSH"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }

 ingress {
  description = "HTTP"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }

 egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }

 tags = {
  Name = "${var.project_name}"
 }
}

resource "aws_subnet" "public" {
 vpc_id = "${aws_vpc.this.id}"
 cidr_block = "10.20.30.0/24"
 availability_zone = "${var.aws_region}a"
 map_public_ip_on_launch = "true"

 tags = {
  Name = "${var.project_name}-public-subnet"
 }
}
resource "aws_subnet" "private" {
 vpc_id = "${aws_vpc.this.id}"
 cidr_block = "10.20.40.0/24"
 availability_zone = "${var.aws_region}b"

 tags = {
  Name = "${var.project_name}-private-subnet"
 }
}

resource "aws_internet_gateway" "this" {
 vpc_id = "${aws_vpc.this.id}"

 tags = {
  Name = "${var.project_name}"
 }
}

resource "aws_route_table" "this" {
 vpc_id = "${aws_vpc.this.id}"

 route {
  cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.this.id}"
 }

 tags = {
  Name = "${var.project_name}"
 }
}

resource "aws_route_table_association" "a" {
 subnet_id = "${aws_subnet.public.id}"
 route_table_id = "${aws_route_table.this.id}"
}
resource "aws_route_table_association" "b" {
 subnet_id = "${aws_subnet.private.id}"
 route_table_id = "${aws_route_table.this.id}"
}

// Dynamically get the latest and greatest ami.
data "aws_ami" "selected" {
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
 ami = "${data.aws_ami.selected.id}"
 instance_type = "t2.micro"
 vpc_security_group_ids = [ "${aws_security_group.this.id}" ]
 subnet_id = "${aws_subnet.public.id}"

  user_data = <<-EOF
              #!/bin/bash
              sudo dnf install -y httpd
              echo "<h1>${var.project_name}</h1><h3>Hello, World!</h3>" > /var/www/html/index.html
              sudo systemctl enable httpd
              sudo systemctl start httpd
              EOF

  user_data_replace_on_change = true

 tags = {
  Name = "${var.project_name}"
 }
}
