# GitHub OIDC Provider Variables

variable "oidc_provider_url" {
  description = "GitHub OIDC provider URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "client_ids" {
  description = "List of client IDs for the OIDC provider"
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

variable "tags" {
  description = "Tags to apply to the OIDC provider"
  type        = map(string)
  default     = {}
}
