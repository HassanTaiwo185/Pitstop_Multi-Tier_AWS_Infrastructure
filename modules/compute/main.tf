# ============================================================
# Compute Module
# Golden AMI pipeline: S3 holds the site and schema; a builder
# EC2 installs Apache/PHP, deploys the site, loads the schema,
# shuts down, and is captured as the golden AMI. The launch
# template then boots web servers from that AMI.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI (x86_64), published by Amazon
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  # All site files, excluding macOS metadata files
  app_files = [for f in fileset(var.app_path, "**") : f if !endswith(f, ".DS_Store")]

  # Fingerprint of site + schema: changes whenever any file changes
  app_hash = sha1(join("", concat(
    [for f in local.app_files : filemd5("${var.app_path}/${f}")],
    [filemd5(var.schema_path)]
  )))
}

# ------------------------------------------------------------
# S3: private bucket holding the site and schema
# ------------------------------------------------------------
resource "aws_s3_bucket" "app" {
  # Account ID keeps the name globally unique
  bucket        = "app-${data.aws_caller_identity.current.account_id}-${var.project_name}"
  force_destroy = true # allows terraform destroy while files are inside

  tags = {
    Name = "app-${var.project_name}"
  }
}

# Block all public access. The builder reads through its IAM role.
resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Site files go under site/ (synced to the web root)
resource "aws_s3_object" "site" {
  for_each = toset(local.app_files)

  bucket = aws_s3_bucket.app.id
  key    = "site/${each.value}"
  source = "${var.app_path}/${each.value}"
  etag   = filemd5("${var.app_path}/${each.value}")
}

# Schema goes under db/ (never served by Apache)
resource "aws_s3_object" "schema" {
  bucket = aws_s3_bucket.app.id
  key    = "db/schema.sql"
  source = var.schema_path
  etag   = filemd5(var.schema_path)
}

# ------------------------------------------------------------
# IAM: role for the builder instance
# ------------------------------------------------------------
resource "aws_iam_role" "builder" {
  name = "builder-role-${var.project_name}"

  # Only EC2 may assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "builder-role-${var.project_name}"
  }
}

# Session Manager access, for debugging the builder if needed
resource "aws_iam_role_policy_attachment" "builder_ssm" {
  role       = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read-only access to the app bucket
resource "aws_iam_role_policy" "builder_s3" {
  name = "read-app-bucket-${var.project_name}"
  role = aws_iam_role.builder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]
    }]
  })
}

# The builder reads the DB credentials to run the schema
resource "aws_iam_role_policy" "builder_db_secret" {
  name = "builder-read-db-secret-${var.project_name}"
  role = aws_iam_role.builder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.db_secret_arn
    }]
  })
}

# EC2 carries an IAM role through an instance profile
resource "aws_iam_instance_profile" "builder" {
  name = "builder-profile-${var.project_name}"
  role = aws_iam_role.builder.name
}

# ------------------------------------------------------------
# Builder EC2: installs everything, loads the schema, shuts down
# ------------------------------------------------------------

# Look up the builder's subnet so we can check it before launching
data "aws_subnet" "builder" {
  id = var.builder_subnet_id
}

resource "aws_instance" "builder" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.builder_subnet_id
  vpc_security_group_ids = [var.web_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.builder.name

  # Never assign a public IP, regardless of the subnet's default
  associate_public_ip_address = false

  # "shutdown -h now" at the end of user_data stops (not terminates) the instance
  instance_initiated_shutdown_behavior = "stop"

  # Require IMDSv2 (token-based instance metadata)
  metadata_options {
    http_tokens = "required"
  }

  user_data = templatefile("${path.module}/builder_user_data.sh", {
    app_bucket    = aws_s3_bucket.app.bucket
    app_hash      = local.app_hash
    db_host       = var.db_host
    db_port       = var.db_port
    db_name       = var.db_name
    db_secret_arn = var.db_secret_arn
    region        = data.aws_region.current.name
  })

  # A changed site or schema means changed user_data, so a new builder and a new AMI
  user_data_replace_on_change = true

  tags = {
    Name = "builder-${var.project_name}"
  }

  lifecycle {
    # BEFORE creating: the builder must be placed in a private subnet
    precondition {
      condition     = !data.aws_subnet.builder.map_public_ip_on_launch
      error_message = "builder_subnet_id (${var.builder_subnet_id}) is a public subnet. The builder must run in a private subnet."
    }

    # AFTER creating: confirm the instance really has no public IP
    postcondition {
      condition     = self.public_ip == null || self.public_ip == ""
      error_message = "Builder instance ${self.id} has a public IP (${self.public_ip}). It must be private-only."
    }
  }

  # Files and permissions must exist before the builder boots
  depends_on = [
    aws_s3_object.site,
    aws_s3_object.schema,
    aws_iam_role_policy.builder_s3,
    aws_iam_role_policy.builder_db_secret,
  ]
}

# Wait until the builder has stopped, meaning user_data finished.
# Runs on your Mac: requires the AWS CLI and exported credentials.
resource "terraform_data" "wait_for_builder" {
  triggers_replace = [aws_instance.builder.id]

  provisioner "local-exec" {
    command = "aws ec2 wait instance-stopped --instance-ids ${aws_instance.builder.id} --region ${data.aws_region.current.name}"
  }
}

# ------------------------------------------------------------
# Golden AMI: snapshot of the stopped, fully configured builder
# ------------------------------------------------------------
resource "aws_ami_from_instance" "golden" {
  name               = "golden-${aws_instance.builder.id}-${var.project_name}"
  source_instance_id = aws_instance.builder.id

  tags = {
    Name    = "golden-ami-${var.project_name}"
    AppHash = local.app_hash # which site + schema version is baked in
  }

  depends_on = [terraform_data.wait_for_builder]

  lifecycle {
    create_before_destroy = true
  }

}

# ------------------------------------------------------------
# IAM: role for the web instances launched by the ASG
# ------------------------------------------------------------
resource "aws_iam_role" "web" {
  name = "web-role-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "web-role-${var.project_name}"
  }
}

# Session Manager access for debugging
resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read exactly one secret: the database credentials
resource "aws_iam_role_policy" "web_db_secret" {
  name = "read-db-secret-${var.project_name}"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "web-profile-${var.project_name}"
  role = aws_iam_role.web.name
}

# ------------------------------------------------------------
# Launch template: golden AMI + runtime DB configuration
# ------------------------------------------------------------
resource "aws_launch_template" "web" {
  name          = "web-lt-${var.project_name}"
  image_id      = aws_ami_from_instance.golden.id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.web_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  metadata_options {
    http_tokens = "required"
  }

  # templatefile() fills in the DB connection details at plan time;
  # the instance fetches the username and password itself at boot
  user_data = base64encode(templatefile("${path.module}/web_user_data.sh", {
    db_host       = var.db_host
    db_port       = var.db_port
    db_name       = var.db_name
    db_secret_arn = var.db_secret_arn
    region        = data.aws_region.current.name
  }))

  # Each new AMI creates a new template version; make it the default
  update_default_version = true

  # Name tag for every instance the ASG launches
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-${var.project_name}"
    }
  }
}



# ------------------------------------------------------------
# Target group: the pool of web instances the ALB sends traffic to
# ------------------------------------------------------------
resource "aws_lb_target_group" "web" {
  name        = "web-tg-${var.project_name}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # How the ALB decides whether an instance is healthy
  health_check {
    path                = "/health.html"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Give in-flight requests 30s to finish before an instance is removed
  deregistration_delay = 30

  tags = {
    Name = "web-tg-${var.project_name}"
  }
}

# ------------------------------------------------------------
# Application Load Balancer: public entry point in the public subnets
# ------------------------------------------------------------
resource "aws_lb" "web" {
  name               = "alb-${var.project_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "alb-${var.project_name}"
  }
}

# Listener: accept HTTP on port 80 and forward to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ------------------------------------------------------------
# Auto Scaling Group: web instances in the private subnets
# ------------------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name                = "web-asg-${var.project_name}"
  min_size            = var.asg_min_size
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.private_subnet_ids

  # Every instance launched is registered in the target group
  target_group_arns = [aws_lb_target_group.web.arn]

  # Replace instances that fail the ALB health check, not just EC2's
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  # When the launch template changes (new AMI), replace instances
  # gradually, keeping at least half of them serving traffic
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# Scale on CPU: add instances above 50% average, remove below
resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-target-${var.project_name}"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}