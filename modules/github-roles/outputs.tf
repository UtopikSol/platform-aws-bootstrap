# GitHub Roles Outputs

output "role_arns" {
  description = "ARNs of the created GitHub roles"
  value = {
    for name, role in aws_iam_role.github :
    name => role.arn
  }
}

output "role_names" {
  description = "Names of the created GitHub roles"
  value = {
    for name, role in aws_iam_role.github :
    name => role.name
  }
}
