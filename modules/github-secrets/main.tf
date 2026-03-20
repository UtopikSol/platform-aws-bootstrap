# GitHub Secrets and Variables Management
# Sets up environment-level secrets and variables for repositories

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

resource "github_actions_environment_secret" "env_secrets" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for env in repo.environments : [
          for secret in env.secrets : {
            key         = "${var.github_org}/${repo.name}/${env.name}/${secret.name}"
            owner       = var.github_org
            repo        = repo.name
            environment = env.name
            name        = secret.name
            value       = secret.file != null ? file(secret.file) : secret.value
          }
        ]
      ]
    ]) : item.key => item
  }

  repository      = each.value.repo
  environment     = each.value.environment
  secret_name     = each.value.name
  plaintext_value = each.value.value
}

resource "github_actions_environment_variable" "env_variables" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for env in repo.environments : [
          for variable in env.variables : {
            key         = "${var.github_org}/${repo.name}/${env.name}/${variable.name}"
            owner       = var.github_org
            repo        = repo.name
            environment = env.name
            name        = variable.name
            value       = variable.value
          }
        ]
      ]
    ]) : item.key => item
  }

  repository    = each.value.repo
  environment   = each.value.environment
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_secret" "repo_secrets" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for secret in repo.secrets : {
          key   = "${var.github_org}/${repo.name}/${secret.name}"
          owner = var.github_org
          repo  = repo.name
          name  = secret.name
          value = secret.file != null ? file(secret.file) : secret.value
        }
      ]
    ]) : item.key => item
  }

  repository      = each.value.repo
  secret_name     = each.value.name
  plaintext_value = each.value.value
}

resource "github_actions_variable" "repo_variables" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for variable in repo.variables : {
          key   = "${var.github_org}/${repo.name}/${variable.name}"
          owner = var.github_org
          repo  = repo.name
          name  = variable.name
          value = variable.value
        }
      ]
    ]) : item.key => item
  }

  repository    = each.value.repo
  variable_name = each.value.name
  value         = each.value.value
}
