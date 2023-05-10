provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "example" {
  instance_tenancy     = "default"
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  tags = {
    Name = "tg-vpc"
  }
}
output "vpc_dflt_rtb" {
description = "VPC default route table"
value = aws_vpc.example.main_route_table_id 
}


#Create Public Subnet
resource "aws_subnet" "pub1" {
  vpc_id                                      = aws_vpc.example.id
  cidr_block                                  = var.pub1
  availability_zone                           = "ap-south-1a"
  enable_resource_name_dns_a_record_on_launch = "true"
  map_public_ip_on_launch                     = "true"
  tags = {
    Name = "Pub1"
  }
}

resource "aws_subnet" "pub2" {
  vpc_id                                      = aws_vpc.example.id
  cidr_block                                  = var.pub2
  availability_zone                           = "ap-south-1b"
  enable_resource_name_dns_a_record_on_launch = "true"
  map_public_ip_on_launch                     = "true"
  tags = {
    Name = "Pub2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "tf-igw"
  }
}

#resource "aws_route_table" "pub-rtb" {
# vpc_id = aws_vpc.example.id

#  route {
#    cidr_block = "0.0.0.0/0"
#    gateway_id = aws_internet_gateway.igw.id
#  }
#  tags = {
#    Name = "pub-rtb"
#  }
#}
resource "aws_route" "pub-rt" {
  route_table_id = aws_vpc.example.main_route_table_id
  gateway_id = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "pub1" {
  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_vpc.example.main_route_table_id
}
resource "aws_route_table_association" "pub2" {
  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_vpc.example.main_route_table_id
}
#private subnet configuration
resource "aws_subnet" "pri1" {
  vpc_id                                      = aws_vpc.example.id
  cidr_block                                  = var.pri1
  availability_zone                           = "ap-south-1a"
  tags = {
    Name = "Private-1"
  }
}
resource "aws_subnet" "pri2" {
  vpc_id                                      = aws_vpc.example.id
  cidr_block                                  = var.pri2
  availability_zone                           = "ap-south-1b"
  tags = {
    Name = "Private-2"
  }
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.pub1.id
  allocation_id = aws_eip.nat_gateway.id
  tags = {
    Name = "gw NAT"
  }
}

resource "aws_route_table" "pri-rtb" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "pri-rtb"
  }
}

resource "aws_route_table_association" "pri1" {
  subnet_id      = aws_subnet.pri1.id
  route_table_id = aws_route_table.pri-rtb.id
}

resource "aws_route_table_association" "pri2" {
  subnet_id      = aws_subnet.pri2.id
  route_table_id = aws_route_table.pri-rtb.id
}

#=================EC2=================================
resource "aws_security_group" "lbsg" {
  vpc_id = aws_vpc.example.id
   ingress {
    description = "TLS from VPC"
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
    "Name" = "alb-sg"
  }
}

resource "aws_security_group" "ec2sg" {
  vpc_id = aws_vpc.example.id
   ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.lbsg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "ec2-sg"
  }
}

resource "aws_instance" "ec2" {
  ami = var.amiid
  instance_type = var.ec2type
  iam_instance_profile = var.iamarn
  subnet_id = "${aws_subnet.pri1.id}"
  security_groups = [
    "${aws_security_group.ec2sg.id}",
  ]
  tags = {
    "Name" = "Terraform-ec2"
  }
  user_data = file("script.sh")
}

resource "aws_lb_target_group" "ec2tg" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.example.id}"
  tags = {
    "Name" = "ec2tg"
  }
}

resource "aws_lb_target_group_attachment" "atch" {
  target_group_arn = "${aws_lb_target_group.ec2tg.arn}"
  target_id        = "${aws_instance.ec2.id}"
  port             = 80
}

resource "aws_alb" "tfalb" {
  name = "tf-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [
    "${aws_security_group.lbsg.id}",
  ]
  subnets = [
    aws_subnet.pub1.id,
    aws_subnet.pub2.id
  ]
}

output "albdns" {
  value = aws_alb.tfalb.dns_name
  description = "ALB Endpoint"
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_alb.tfalb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ec2tg.arn
  }
}