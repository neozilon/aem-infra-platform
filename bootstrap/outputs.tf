output "repository_full_name" {
  description = "owner/name of the created repository."
  value       = github_repository.platform.full_name
}

output "repository_html_url" {
  description = "Web URL of the repository."
  value       = github_repository.platform.html_url
}

output "repository_clone_url_https" {
  description = "HTTPS clone URL — use to push the platform code."
  value       = github_repository.platform.http_clone_url
}

output "repository_clone_url_ssh" {
  description = "SSH clone URL."
  value       = github_repository.platform.ssh_clone_url
}

output "default_branch" {
  description = "Protected default branch."
  value       = var.default_branch
}

output "environments" {
  description = "Deployment environments created."
  value       = sort([for e in github_repository_environment.env : e.environment])
}
