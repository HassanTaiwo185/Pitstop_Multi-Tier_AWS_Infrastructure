
# Networking Module
# Creates the Pitstop VPC with public and private subnets across
# two availability zones, an Internet Gateway for public access,
# and a NAT Gateway for outbound-only internet from private subnets.
module "networking" {
  source = "./modules/networking"

  project_name = "pitstop"
  cidr         = "10.0.0.0/16"

  public_subnets = {
    "public-1" = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    "public-2" = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  }

  private_subnets = {
    "private-1" = { cidr = "10.0.11.0/24", az = "us-east-1a" }
    "private-2" = { cidr = "10.0.12.0/24", az = "us-east-1b" }
  }


}