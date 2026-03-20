# GitHub Secrets and Variables Management
# Sets up environment-level secrets and variables for repositories

resource "github_actions_environment_secret" "repo_secrets" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for env in repo.environments : [
          for secret in env.secrets : {
            key         = "${repo.owner}/${repo.name}/${env.name}/${secret.name}"
            owner       = repo.owner
            repo        = repo.name
            environment = env.name
            name        = secret.name
            value       = secret.value
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

resource "github_actions_environment_variable" "repo_variables" {
  for_each = {
    for item in flatten([
      for repo in var.repositories : [
        for env in repo.environments : [
          for variable in env.variables : {
            key         = "${repo.owner}/${repo.name}/${env.name}/${variable.name}"
            owner       = repo.owner
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
