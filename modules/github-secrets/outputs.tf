output "secrets" {
  description = "Map of managed environment secrets by resource key"
  value       = github_actions_environment_secret.repo_secrets
  sensitive   = true
}

output "variables" {
  description = "Map of managed environment variables by resource key"
  value       = github_actions_environment_variable.repo_variables
}
