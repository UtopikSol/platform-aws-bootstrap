# Outputs for GitHub Bootstrap

output "oidc_provider_arn" {
  description = "ARN of the GitHub OpenID Connect Provider"
  value       = module.github_oidc.oidc_provider_arn
}

output "role_arns" {
  description = "ARNs of the created GitHub OIDC roles"
  value       = module.github_roles.role_arns
}

output "role_names" {
  description = "Names of the created GitHub OIDC roles"
  value       = module.github_roles.role_names
}

output "ssm_parameters" {
  description = "SSM Parameters created for configuration export"
  value = {
    oidc_provider_arn = aws_ssm_parameter.oidc_provider_arn.name
    role_arns         = { for name, param in aws_ssm_parameter.github_roles : name => param.name }
  }
}
