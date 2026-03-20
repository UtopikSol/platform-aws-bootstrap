# GitHub OIDC Provider for AWS
# This module creates the OpenID Connect provider that allows GitHub Actions to assume IAM roles

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get the thumbprint of GitHub's OIDC provider certificate
data "tls_certificate" "github" {
  url = var.oidc_provider_url
}

# Create the GitHub OpenID Connect provider
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = var.client_ids
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = var.oidc_provider_url

  tags = merge(
    var.tags,
    {
      Name        = "github-oidc-provider"
      Description = "OpenID Connect provider for GitHub Actions"
    }
  )
}
