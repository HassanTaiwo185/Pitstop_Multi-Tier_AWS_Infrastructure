variable "project_name" {
  description = "Project name appended to all resource names"
  type        = string
}

variable "app_path" {
  description = "Local path to the site folder uploaded to S3"
  type        = string
}

variable "schema_path" {
  description = "Local path to the database schema SQL file"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the builder and web servers"
  type        = string
  default     = "t3.micro" # free tier eligible
}

variable "builder_subnet_id" {
  description = "Private subnet where the builder instance runs"
  type        = string
}

variable "web_security_group_id" {
  description = "Security group for the builder and web servers"
  type        = string
}

variable "db_host" {
  description = "RDS endpoint hostname"
  type        = string
}

variable "db_port" {
  description = "RDS port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret with the DB username and password"
  type        = string
}


variable "vpc_id" {
  description = "VPC for the target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the Auto Scaling Group"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group for the ALB"
  type        = string
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}