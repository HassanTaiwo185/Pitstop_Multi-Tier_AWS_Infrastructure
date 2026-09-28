terraform {
  required_version = "=1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  cloud {
    organization = "HASSAN_HCP"

    workspaces {
      name = "Pitstop_Multi-Tier_AWS_Infrastructure"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = local.project_name
      ManagedBy = "Terraform"
    }
  }


}