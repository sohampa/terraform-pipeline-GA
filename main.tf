# Specify the provider
provider "aws" {
  region = "us-east-1" # Change this to your preferred region
}

locals {
  environment   = terraform.workspace
  instance_name  = "terraform-ec2-${local.environment}"
  sg_name        = "ec2_sg_${local.environment}"
}

# Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the first subnet from the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a security group allowing SSH access
resource "aws_security_group" "ec2_sg" {
  name        = local.sg_name
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name        = local.sg_name
    Environment = local.environment
  }
}

# Create EC2 instance
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = var.key_name

  tags = {
    Name        = local.instance_name
    Environment = local.environment
  }
}

# Output the instance public IP
output "instance_public_ip" {
  value = aws_instance.example.public_ip
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}
