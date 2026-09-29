output "app_bucket_name" {
  description = "Name of the S3 bucket holding the site"
  value       = aws_s3_bucket.app.bucket
}

output "builder_instance_id" {
  description = "ID of the (stopped) builder instance"
  value       = aws_instance.builder.id
}

output "golden_ami_id" {
  description = "ID of the golden AMI used by the launch template"
  value       = aws_ami_from_instance.golden.id
}

output "alb_dns_name" {
  description = "Public address of the load balancer"
  value       = aws_lb.web.dns_name
}