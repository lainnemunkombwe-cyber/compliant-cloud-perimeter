# Standard Alignment: NIST CSF PR.AC-4 (Access Management)
# This block tells Terraform which cloud provider to use and where to deploy.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}