

resource "aws_db_subnet_group" "this" {
  name       = "db-subnet-group-${var.project_name}"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "db-subnet-group-${var.project_name}"
  }
}


# Pitstop PostgreSQL database (private, single-AZ, free tier)
resource "aws_db_instance" "this" {
  identifier     = "db-${var.project_name}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage (free tier: 20 GB General Purpose SSD, no autoscaling)
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  # Initial database and master user
  db_name  = var.db_name
  username = var.db_username

  # RDS generates the password and stores it in Secrets Manager,
  # encrypted with the default aws/secretsmanager KMS key
  manage_master_user_password = true

  # Networking: private subnets, db security group, never public
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false
  multi_az               = false

  # Backups (free plan accounts only allow short retention)
  backup_retention_period = 1

  # Learning project: allow clean terraform destroy
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "db-${var.project_name}"
  }
}

