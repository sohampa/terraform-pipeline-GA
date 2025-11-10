# Specify the provider
provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "temp-soham-s3"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # dynamodb_table = "terraform-lock" # Optional: for state locking
  }
}

locals {
  environment    = terraform.workspace
  instance_name  = "terraform-ec2-${local.environment}"
  sg_name        = "ec2_sg_${local.environment}"
  secret_name    = "terraform/${local.environment}" # ✅ FIXED
}

# Fetch secret from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "ec2_config" {
  secret_id = local.secret_name
}

# Decode JSON secret
locals {
  ec2_config = jsondecode(data.aws_secretsmanager_secret_version.ec2_config.secret_string)
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

# Get default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for SSH
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

# EC2 instance
resource "aws_instance" "example" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.ec2_config.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = local.ec2_config.key_name

  tags = {
    Name        = local.instance_name
    Environment = local.environment
  }
}

# Create S3 bucket
resource "aws_s3_bucket" "terraform_soham_bucket" {
  bucket = "terraform-soham-bucket"

  tags = {
    Name        = "terraform-soham-bucket"
    Environment = local.environment
  }
}

# Output instance public IP
output "instance_public_ip" {
  value = aws_instance.example.public_ip
}
