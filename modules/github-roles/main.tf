# GitHub Repository IAM Roles
# This module creates IAM roles for GitHub repositories with OIDC trust relationships

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM role for each GitHub repository
resource "aws_iam_role" "github" {
  for_each = { for repo in var.repositories : repo.name => repo }

  name               = "github-${each.value.owner}-${each.value.name}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role[each.key].json
  description        = "OIDC role for GitHub repository ${each.value.owner}/${each.value.name}"

  tags = merge(
    var.tags,
    {
      Name              = "github-${each.value.owner}-${each.value.name}"
      GitHubOwner       = each.value.owner
      GitHubRepo        = each.value.name
      GitHubPermissions = each.value.permissions
    }
  )
}

# Trust policy for each GitHub repository
data "aws_iam_policy_document" "github_assume_role" {
  for_each = { for repo in var.repositories : repo.name => repo }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.assume_role_subjects[each.key]
    }
  }
}

# Attach permissions policy to each role
resource "aws_iam_role_policy" "github_permissions" {
  for_each = { for repo in var.repositories : repo.name => repo }

  name   = "${aws_iam_role.github[each.key].name}-policy"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.github_permissions[each.key].json
}

# Permission policies based on permission level
data "aws_iam_policy_document" "github_permissions" {
  for_each = { for repo in var.repositories : repo.name => repo }

  # Common permissions for all levels
  statement {
    sid    = "SSMParameterStore"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:*:*:parameter/cdk-bootstrap/*",
      "arn:aws:ssm:*:*:parameter/utopiksol/*",
    ]
  }

  # Permission-level specific statements
  dynamic "statement" {
    for_each = local.permission_statements[each.value.permissions]
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

# Local permissions mapping
locals {
  assume_role_subjects = {
    for repo in var.repositories : repo.name => (
      length(repo.environments) > 0 ? [
        for env in repo.environments : "repo:${repo.owner}/${repo.name}:environment:${env}"
      ] :
      ["repo:${repo.owner}/${repo.name}:*"]
    )
  }

  permission_statements = {
    "bootstrap" = [
      {
        sid    = "AssumeGitHubRoles"
        effect = "Allow"
        actions = [
          "sts:AssumeRole"
        ]
        resources = [
          "arn:aws:iam::*:role/github-*"
        ]
      },
      {
        sid    = "S3Bootstrap"
        effect = "Allow"
        actions = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
        ]
        resources = [
          "arn:aws:s3:::cdk-hnb659fds-assets-*",
          "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
        ]
      },
      {
        sid    = "CloudFormationBootstrap"
        effect = "Allow"
        actions = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackResource",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate",
          "cloudformation:ListStacks",
        ]
        resources = [
          "arn:aws:cloudformation:*:*:stack/*",
        ]
      },
      {
        sid    = "IAMBootstrap"
        effect = "Allow"
        actions = [
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
        ]
        resources = [
          "arn:aws:iam::*:role/*",
          "arn:aws:iam::*:oidc-provider/*",
        ]
      },
      {
        sid    = "SSMBootstrap"
        effect = "Allow"
        actions = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
        ]
        resources = [
          "arn:aws:ssm:*:*:parameter/cdk-bootstrap/*",
          "arn:aws:ssm:*:*:parameter/utopiksol/*",
        ]
      },
    ]
    "full" = [
      {
        sid    = "AssumeGitHubRoles"
        effect = "Allow"
        actions = [
          "sts:AssumeRole"
        ]
        resources = [
          "arn:aws:iam::*:role/github-*"
        ]
      },
      {
        sid    = "S3FullAccess"
        effect = "Allow"
        actions = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
        ]
        resources = [
          "arn:aws:s3:::cdk-hnb659fds-assets-*",
          "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
        ]
      },
      {
        sid    = "CloudFormationFullAccess"
        effect = "Allow"
        actions = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackResource",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate",
          "cloudformation:ListStacks",
        ]
        resources = [
          "arn:aws:cloudformation:*:*:stack/*",
        ]
      },
      {
        sid    = "IAMFullAccess"
        effect = "Allow"
        actions = [
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:GetOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
        ]
        resources = [
          "arn:aws:iam::*:role/*",
          "arn:aws:iam::*:oidc-provider/*",
        ]
      },
      {
        sid    = "SSMFullAccess"
        effect = "Allow"
        actions = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
        ]
        resources = [
          "arn:aws:ssm:*:*:parameter/*",
        ]
      },
    ]
    "deploy" = [
      {
        sid    = "S3DeployAccess"
        effect = "Allow"
        actions = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
        ]
        resources = [
          "arn:aws:s3:::cdk-hnb659fds-assets-*",
          "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
        ]
      },
      {
        sid    = "CloudFormationDeployAccess"
        effect = "Allow"
        actions = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackResource",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate",
          "cloudformation:ListStacks",
        ]
        resources = [
          "arn:aws:cloudformation:*:*:stack/*",
        ]
      },
      {
        sid    = "LambdaDeployAccess"
        effect = "Allow"
        actions = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:ListFunctions",
        ]
        resources = [
          "arn:aws:lambda:*:*:function:*",
        ]
      },
      {
        sid    = "RDSDeployAccess"
        effect = "Allow"
        actions = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ModifyDBInstance",
          "rds:ModifyDBCluster",
        ]
        resources = [
          "arn:aws:rds:*:*:db/*",
        ]
      },
    ]
    "read-only" = [
      {
        sid    = "CloudWatchReadOnly"
        effect = "Allow"
        actions = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
        ]
        resources = [
          "*",
        ]
      },
      {
        sid    = "CloudWatchLogsReadOnly"
        effect = "Allow"
        actions = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents",
        ]
        resources = [
          "arn:aws:logs:*:*:log-group:*",
        ]
      },
      {
        sid    = "DescribeReadOnly"
        effect = "Allow"
        actions = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "cloudformation:ListStacks",
          "cloudformation:DescribeStacks",
        ]
        resources = [
          "*",
        ]
      },
    ]
  }
}
