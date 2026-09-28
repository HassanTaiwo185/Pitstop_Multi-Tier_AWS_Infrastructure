variable "project_name" {
  type = string
}


variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (at least 2 AZs)"
  type        = list(string)
}


variable "db_security_group_id" {
  description = "Security group ID for the RDS instance"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "pitstop"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "pitstop_admin"
}