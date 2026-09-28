output "db_endpoint" {
  description = "Hostname of the database (without port)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}