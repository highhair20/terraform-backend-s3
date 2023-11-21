provider "aws" {
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

terraform {
  backend "s3" {}
}


resource "aws_vpc" "this" {
 cidr_block = "10.0.0.0/16"
 instance_tenancy = "default"
 enable_dns_hostnames = "true"

 tags = {
  Name = "sample-project-a"
 }
}

resource "aws_security_group" "this" {
 name = "sample-project-a"
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
  Name = "sample-project-a"
 }
}

resource "aws_subnet" "public" {
 vpc_id = "${aws_vpc.this.id}"
 cidr_block = "192.168.0.0/24"
 availability_zone = "${var.aws_region}a"
 map_public_ip_on_launch = "true"

 tags = {
  Name = "sample-project-a-public-subnet"
 }
}
resource "aws_subnet" "private" {
 vpc_id = "${aws_vpc.this.id}"
 cidr_block = "192.168.1.0/24"
 availability_zone = "${var.aws_region}b"

 tags = {
  Name = "sample-project-a-private-subnet"
 }
}

resource "aws_internet_gateway" "this" {
 vpc_id = "${aws_vpc.this.id}"

 tags = {
  Name = "sample-project-a"
 }
}

resource "aws_route_table" "this" {
 vpc_id = "${aws_vpc.this.id}"

 route {
  cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.this.id}"
 }

 tags = {
  Name = "sample-project-a"
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

resource "aws_instance" "wordpress" {
 ami = "ami-03a115bbd6928e698"
 instance_type = "t2.micro"
 vpc_security_group_ids = [ "${aws_security_group.this.id}" ]
 subnet_id = "${aws_subnet.public.id}"

 tags = {
  Name = "sample-project-a"
 }
}