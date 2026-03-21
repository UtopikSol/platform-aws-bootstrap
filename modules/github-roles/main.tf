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

  name               = "github-${var.github_org}-${each.value.name}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role[each.key].json
  description        = "OIDC role for GitHub repository ${var.github_org}/${each.value.name}"

  tags = merge(
    var.tags,
    {
      Name              = "github-${var.github_org}-${each.value.name}"
      GitHubOwner       = var.github_org
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
        for env in repo.environments : "repo:${var.github_org}/${repo.name}:environment:${env.name}"
      ] :
      ["repo:${var.github_org}/${repo.name}:*"]
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
    "network" = [
      {
        sid    = "CloudFormationNetworkAccess"
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
          "cloudformation:ListStackResources",
        ]
        resources = [
          "arn:aws:cloudformation:*:*:stack/*",
        ]
      },
      {
        sid    = "VPCAndNetworkAccess"
        effect = "Allow"
        actions = [
          "ec2:CreateVpc",
          "ec2:ModifyVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:CreateSubnet",
          "ec2:ModifySubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateRouteTable",
          "ec2:ModifyRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ReplaceRoute",
          "ec2:CreateSecurityGroup",
          "ec2:ModifySecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*",
          "ec2:CreateNetworkAcl",
          "ec2:ModifyNetworkAcl",
          "ec2:DeleteNetworkAcl",
          "ec2:DescribeNetworkAcls",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAclEntry",
          "ec2:ReplaceNetworkAclEntry",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:DescribeInternetGateways",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:CreateVpnGateway",
          "ec2:DeleteVpnGateway",
          "ec2:DescribeVpnGateways",
          "ec2:AttachVpnGateway",
          "ec2:DetachVpnGateway",
          "ec2:CreateVpcPeeringConnection",
          "ec2:DeleteVpcPeeringConnection",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:AcceptVpcPeeringConnection",
          "ec2:RejectVpcPeeringConnection",
          "ec2:CreateVpcEndpoint",
          "ec2:DeleteVpcEndpoint",
          "ec2:DescribeVpcEndpoints",
          "ec2:ModifyVpcEndpoint",
          "ec2:DescribeVpcEndpointServices",
          "ec2:CreateNetworkInterface",
          "ec2:ModifyNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
        ]
        resources = [
          "arn:aws:ec2:*:*:vpc/*",
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:route-table/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:network-acl/*",
          "arn:aws:ec2:*:*:internet-gateway/*",
          "arn:aws:ec2:*:*:nat-gateway/*",
          "arn:aws:ec2:*:*:address/*",
          "arn:aws:ec2:*:*:vpn-gateway/*",
          "arn:aws:ec2:*:*:vpc-peering-connection/*",
          "arn:aws:ec2:*:*:vpc-endpoint/*",
          "arn:aws:ec2:*:*:network-interface/*",
        ]
      },
      {
        sid    = "Route53Access"
        effect = "Allow"
        actions = [
          "route53:CreateHostedZone",
          "route53:UpdateHostedZone",
          "route53:DeleteHostedZone",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetChange",
          "route53:ListTagsForResource",
          "route53:ChangeTagsForResource",
          "route53:CreateQueryLoggingConfig",
          "route53:DeleteQueryLoggingConfig",
          "route53:ListQueryLoggingConfigs",
        ]
        resources = [
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*",
        ]
      },
      {
        sid    = "IAMNetworkRoleAccess"
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
          "iam:CreatePolicy",
          "iam:UpdatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:ListPolicies",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
        ]
        resources = [
          "arn:aws:iam::*:role/*",
          "arn:aws:iam::*:policy/*",
        ]
      },
      {
        sid    = "TerraformStateAccess"
        effect = "Allow"
        actions = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketLocation",
        ]
        resources = [
          "arn:aws:s3:::*-terraform-state-*",
          "arn:aws:s3:::*-terraform-state-*/*",
        ]
      },
      {
        sid    = "DynamoDBStateLocking"
        effect = "Allow"
        actions = [
          "dynamodb:DescribeTable",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        resources = [
          "arn:aws:dynamodb:*:*:table/terraform-locks",
          "arn:aws:dynamodb:*:*:table/*-terraform-locks",
        ]
      },
      {
        sid    = "CloudWatchLogsNetworkAccess"
        effect = "Allow"
        actions = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents",
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream",
        ]
        resources = [
          "arn:aws:logs:*:*:log-group:/aws/vpc/*",
          "arn:aws:logs:*:*:log-group:*",
        ]
      },
      {
        sid    = "TaggingAccess"
        effect = "Allow"
        actions = [
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:DescribeTagOptions",
        ]
        resources = [
          "*",
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
