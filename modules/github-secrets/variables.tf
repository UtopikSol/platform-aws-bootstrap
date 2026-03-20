variable "repositories" {
  description = "GitHub repositories to configure secrets and variables for. Requires 'environments' to specify target environments."
  type = list(object({
    owner       = string
    name        = string
    permissions = optional(string, "deploy")
    environments = optional(list(object({
      name = string
      secrets = optional(list(object({
        name  = string
        value = string
      })), [])
      variables = optional(list(object({
        name  = string
        value = string
      })), [])
    })), [])
  }))
}
