variable "repositories" {
  description = "GitHub repositories to configure secrets and variables for. Requires 'environments' to specify target environments."
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
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}
