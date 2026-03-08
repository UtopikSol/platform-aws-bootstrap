import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export class GitHubOIDCStack extends Construct {
  public readonly oidcProvider: iam.OpenIdConnectProvider;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // GitHub thumbprint for OIDC provider
    // See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
    const githubThumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1";

    // Create the GitHub OIDC provider
    this.oidcProvider = new iam.OpenIdConnectProvider(
      this,
      "GitHubOIDCProvider",
      {
        url: "https://token.actions.githubusercontent.com",
        clientIds: ["sts.amazonaws.com"],
        thumbprints: [githubThumbprint],
      },
    );

    // Output the provider ARN
    const stack = cdk.Stack.of(this);
    new cdk.CfnOutput(this, "OIDCProviderArn", {
      value: this.oidcProvider.openIdConnectProviderArn,
      description: "GitHub OIDC Provider ARN",
      exportName: "GitHubOIDCProviderArn",
    });
  }
}
