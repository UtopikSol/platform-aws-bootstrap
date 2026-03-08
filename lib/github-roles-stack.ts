import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export interface GitHubRepoConfig {
  owner: string;
  name: string;
  environments?: string[];
  branches?: string[];
  permissions?: "bootstrap" | "full" | "deploy" | "read-only";
}

export interface GitHubRolesStackProps {
  oidcProvider: iam.OpenIdConnectProvider;
  repositories: GitHubRepoConfig[];
  mgmtAccountRoleArn?: string;
}

export class GitHubRolesStack extends Construct {
  public readonly roleArns: Record<string, string> = {};

  constructor(scope: Construct, id: string, props: GitHubRolesStackProps) {
    super(scope, id);

    const { oidcProvider, repositories } = props;

    // Create roles for each repository
    repositories.forEach((repo) => {
      const roleName = `github-${repo.owner}-${repo.name}`;

      // Build the conditions for the role trust policy
      const conditions: Record<string, any> = {
        StringEquals: {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        },
      };

      // Scope by repository
      const repoCondition = `repo:${repo.owner}/${repo.name}:*`;
      conditions["StringLike"] = conditions["StringLike"] || {};
      conditions["StringLike"]["token.actions.githubusercontent.com:sub"] =
        repoCondition;

      // Create the role
      const role = new iam.Role(this, `GitHubRole-${repo.name}`, {
        roleName,
        assumedBy: new iam.OpenIdConnectPrincipal(oidcProvider, conditions),
        description: `OIDC role for GitHub repository ${repo.owner}/${repo.name}`,
      });

      // Determine permissions level (default to "deploy" for safety)
      const permissionLevel = repo.permissions || "deploy";

      // Apply permissions based on level
      this.applyPermissions(role, permissionLevel);

      // Store the role ARN
      this.roleArns[repo.name] = role.roleArn;

      // Output the role ARN
      new cdk.CfnOutput(this, `RoleArn-${repo.name}`, {
        value: role.roleArn,
        description: `OIDC role ARN for ${repo.owner}/${repo.name}`,
        exportName: `GitHubRoleArn-${repo.owner}-${repo.name}`,
      });
    });
  }

  /**
   * Apply permissions to a role based on permission level
   * Permission levels:
   * - "bootstrap": Role/OIDC provider management (for infrastructure repos)
   * - "full": All permissions (IAM, CloudFormation, S3, etc.)
   * - "deploy": CloudFormation, S3, but no IAM changes
   * - "read-only": Only read/describe operations
   */
  private applyPermissions(
    role: iam.Role,
    level: "bootstrap" | "full" | "deploy" | "read-only",
  ): void {
    // Common permissions for all levels
    role.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["ssm:GetParameter"],
        resources: ["arn:aws:ssm:*:*:parameter/cdk-bootstrap/*"],
      }),
    );

    if (level === "bootstrap") {
      // Bootstrap permissions: manage infrastructure, roles, and OIDC providers
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: ["sts:AssumeRole"],
          resources: ["arn:aws:iam::*:role/github-*"],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
          ],
          resources: [
            "arn:aws:s3:::cdk-hnb659fds-assets-*",
            "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
          ],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "cloudformation:CreateStack",
            "cloudformation:UpdateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:DescribeStackResource",
            "cloudformation:DescribeStackResources",
            "cloudformation:GetTemplate",
            "cloudformation:ListStacks",
          ],
          resources: ["arn:aws:cloudformation:*:*:stack/*"],
        }),
      );

      // Full IAM and OIDC provider management for infrastructure setup
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
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
          ],
          resources: [
            "arn:aws:iam::*:role/*",
            "arn:aws:iam::*:oidc-provider/*",
          ],
        }),
      );
    } else if (level === "full") {
      // Full permissions: everything
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: ["sts:AssumeRole"],
          resources: ["arn:aws:iam::*:role/github-*"],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
          ],
          resources: [
            "arn:aws:s3:::cdk-hnb659fds-assets-*",
            "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
          ],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "cloudformation:CreateStack",
            "cloudformation:UpdateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:DescribeStackResource",
            "cloudformation:DescribeStackResources",
            "cloudformation:GetTemplate",
            "cloudformation:ListStacks",
          ],
          resources: ["arn:aws:cloudformation:*:*:stack/*"],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
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
          ],
          resources: [
            "arn:aws:iam::*:role/*",
            "arn:aws:iam::*:oidc-provider/*",
          ],
        }),
      );
    } else if (level === "deploy") {
      // Deploy permissions: CloudFormation, S3, but no IAM
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
          ],
          resources: [
            "arn:aws:s3:::cdk-hnb659fds-assets-*",
            "arn:aws:s3:::cdk-hnb659fds-assets-*/*",
          ],
        }),
      );

      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "cloudformation:CreateStack",
            "cloudformation:UpdateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:DescribeStackResource",
            "cloudformation:DescribeStackResources",
            "cloudformation:GetTemplate",
            "cloudformation:ListStacks",
          ],
          resources: ["arn:aws:cloudformation:*:*:stack/*"],
        }),
      );

      // Allow passing existing roles but not creating new ones
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: ["iam:PassRole", "iam:GetRole"],
          resources: ["arn:aws:iam::*:role/*"],
        }),
      );
    } else if (level === "read-only") {
      // Read-only permissions: describe and list operations only
      role.addToPrincipalPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetObject",
            "s3:ListBucket",
            "cloudformation:DescribeStacks",
            "cloudformation:DescribeStackResource",
            "cloudformation:DescribeStackResources",
            "cloudformation:GetTemplate",
            "cloudformation:ListStacks",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:GetLogEvents",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricStatistics",
          ],
          resources: ["*"],
        }),
      );
    }
  }
}
