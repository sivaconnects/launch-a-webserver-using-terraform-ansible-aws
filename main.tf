terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = "eu-north-1"
}


resource "aws_instance" "web_server" {
  ami           = "ami-073130f74f5ffb161"
  instance_type = "t3.micro"
  key_name = "aws_keypair"

  tags = {
    Name = "nginx-web-server"
  }
}

