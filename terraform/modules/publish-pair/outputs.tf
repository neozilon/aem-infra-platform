output "publish_instance_id" {
  description = "Publish EC2 instance ID."
  value       = aws_instance.publish.id
}

output "publish_private_ip" {
  description = "Publish private IP."
  value       = aws_instance.publish.private_ip
}

output "publish_security_group_id" {
  description = "Publish security group ID."
  value       = aws_security_group.publish.id
}

output "dispatcher_instance_id" {
  description = "Dispatcher EC2 instance ID."
  value       = aws_instance.dispatcher.id
}

output "dispatcher_private_ip" {
  description = "Dispatcher private IP (ALB target)."
  value       = aws_instance.dispatcher.private_ip
}

output "dispatcher_security_group_id" {
  description = "Dispatcher security group ID."
  value       = aws_security_group.dispatcher.id
}
