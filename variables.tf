# Variables for GitHub Bootstrap

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "oidc_provider_url" {
  description = "GitHub OIDC Provider URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "oidc_client_ids" {
  description = "Client IDs for GitHub OIDC Provider"
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

variable "repositories" {
  description = "GitHub repositories to configure for OIDC. Use `environments` to scope trust policies to specific GitHub Environments."
  type = list(object({
    name        = string
    permissions = optional(string, "deploy")
    environments = optional(list(object({
      name = string
      secrets = optional(list(object({
        name  = string
        value = optional(string)
        file  = optional(string)
      })), [])
      variables = optional(list(object({
        name  = string
        value = string
      })), [])
    })), [])
    secrets = optional(list(object({
      name  = string
      value = optional(string)
      file  = optional(string)
    })), [])
    variables = optional(list(object({
      name  = string
      value = string
    })), [])
  }))

  validation {
    condition = alltrue([
      for repo in var.repositories :
      contains(["bootstrap", "full", "deploy", "network", "read-only"], repo.permissions)
    ])
    error_message = "All permissions must be one of: bootstrap, full, deploy, network, read-only"
  }
}

variable "github_token" {
  description = "GitHub API token. If not provided, uses GITHUB_TOKEN environment variable. Requires admin:org scope."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
