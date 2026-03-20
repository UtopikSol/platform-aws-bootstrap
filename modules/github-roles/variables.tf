# GitHub Roles Variables

variable "oidc_provider_arn" {
  description = "ARN of the GitHub OpenID Connect provider"
  type        = string
}

variable "repositories" {
  description = "List of GitHub repositories to create roles for. Use `environments` to scope trust policies to specific GitHub Environments."
  type = list(object({
    owner        = string
    name         = string
    permissions  = optional(string, "deploy")
    environments = optional(list(string), [])
  }))
}

variable "tags" {
  description = "Tags to apply to the roles"
  type        = map(string)
  default     = {}
}
