import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { GitHubOIDCStack } from "./github-oidc-stack";
import { GitHubRolesStack, GitHubRepoConfig } from "./github-roles-stack";

export interface CoreBootstrapStackProps extends cdk.StackProps {
  owner: string;
  repositories: GitHubRepoConfig[];
}

export class CoreBootstrapStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: CoreBootstrapStackProps) {
    super(scope, id, props);

    const { owner, repositories } = props;

    // Create the OIDC provider construct
    const oidcStack = new GitHubOIDCStack(this, "GitHubOIDC");

    // Create the roles construct
    const rolesStack = new GitHubRolesStack(this, "GitHubRoles", {
      oidcProvider: oidcStack.oidcProvider,
      repositories,
    });
  }
}
