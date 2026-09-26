output "security_group_ids" {
  description = "Map of tier name => security group ID"
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}