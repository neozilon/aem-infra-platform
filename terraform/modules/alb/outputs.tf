output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route 53 alias records)."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "ALB security group ID (grant as ingress source on Author/Dispatcher)."
  value       = aws_security_group.alb.id
}

output "dispatcher_target_group_arn" {
  description = "Dispatcher target group ARN — attach Dispatcher instances in the env root."
  value       = aws_lb_target_group.dispatcher.arn
}

output "author_target_group_arn" {
  description = "Author target group ARN, or empty if author_host was not set."
  value       = local.author_enabled ? aws_lb_target_group.author[0].arn : ""
}
