

# Pitstop Virtual private cloud
resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-${var.project_name}"
  }

}

# Pitstop Public subnet
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  map_public_ip_on_launch = true

  tags = {
    Name = "${each.key}-subnet-${var.project_name}"
  }
}


# Pitstop Private subnet
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${each.key}-subnet-${var.project_name}"
  }

}

# Pitstop Internet gateway for internet connection
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.project_name}"
  }
}

# Elastic IP id 
resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip-${var.project_name}"
  }

  depends_on = [aws_internet_gateway.igw]
}


# Pitstop Nat gateway to allow private instances into internet connection
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[keys(var.public_subnets)[0]].id

  tags = {
    Name = "nat-${var.project_name}"
  }

  depends_on = [aws_internet_gateway.igw]

}


# Pitstop Public Route table for routing traffic
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt-${var.project_name}"
  }
}

# Pitstop Private Route table for routing traffic
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt-${var.project_name}"
  }
}


# Public Route table association
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# Private Route table association
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
