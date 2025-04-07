output "instance_ids" {
  description = "IDs of created instances"
  value       = aws_instance.t4g_instances[*].id
}

output "public_ips" {
  description = "Public IP addresses of instances"
  value       = aws_instance.t4g_instances[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of instances"
  value       = aws_instance.t4g_instances[*].private_ip
}
