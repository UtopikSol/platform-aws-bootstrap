# GitHub OIDC Provider Outputs

output "oidc_provider_arn" {
  description = "ARN of the GitHub OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "oidc_provider_url" {
  description = "URL of the GitHub OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.github.url
}
