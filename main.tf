# Terraform Root Configuration
# AWS bootstrap infrastructure for GitHub Actions OIDC integration

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "s3" {
  #   bucket         = "my-terraform-state"
  #   key            = "github-bootstrap/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "GitHub-Bootstrap"
      ManagedBy = "Terraform"
    }
  }
}

provider "github" {
  token = var.github_token != "" ? var.github_token : null
}

provider "tls" {}

# GitHub OIDC Provider Module
module "github_oidc" {
  source = "./modules/github-oidc"

  oidc_provider_url = var.oidc_provider_url
  client_ids        = var.oidc_client_ids
  tags              = var.tags
}

# GitHub Roles Module
module "github_roles" {
  source = "./modules/github-roles"

  oidc_provider_arn = module.github_oidc.oidc_provider_arn
  repositories      = var.repositories
  tags              = var.tags
}

# GitHub Secrets and Variables Module
module "github_secrets" {
  source = "./modules/github-secrets"

  repositories = var.repositories
}

# CloudFormation export for other stacks
locals {
  export_oidc_provider_arn = "GitHubOIDCProviderArn"
}

# Output CloudFormation exports (for CDK/CFN compatibility)
resource "aws_ssm_parameter" "oidc_provider_arn" {
  name        = "/github-bootstrap/oidc_provider_arn"
  description = "GitHub OIDC Provider ARN"
  type        = "String"
  value       = module.github_oidc.oidc_provider_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "github_roles" {
  for_each = module.github_roles.role_arns

  name        = "/github-bootstrap/roles/${each.key}"
  description = "GitHub OIDC Role ARN for ${each.key}"
  type        = "String"
  value       = each.value

  tags = var.tags
}
