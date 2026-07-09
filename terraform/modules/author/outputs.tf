output "instance_id" {
  description = "Author EC2 instance ID."
  value       = aws_instance.author.id
}

output "private_ip" {
  description = "Author private IP."
  value       = aws_instance.author.private_ip
}

output "security_group_id" {
  description = "Author security group ID (target for ALB / replication rules)."
  value       = aws_security_group.author.id
}

output "iam_role_arn" {
  description = "Author instance role ARN."
  value       = aws_iam_role.author.arn
}
