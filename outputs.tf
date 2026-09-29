output "website_url" {
  description = "Open this in your browser"
  value       = "http://${module.compute.alb_dns_name}"
}