# GitHub Actions OIDC Integration Guide

This guide explains how to set up and use the GitHub OIDC integration for AWS deployments across your repositories.

## Overview

The `platform-aws-core-bootstrap` repository creates the foundational AWS infrastructure (OIDC provider and IAM roles). This guide shows how to:

1. Deploy the bootstrap stack to your AWS account
2. Configure GitHub Actions secrets for each repository
3. Use the OIDC role in your GitHub Actions workflows

## Initial Setup

### Step 1: Deploy Bootstrap Stack

This needs to be done once in your AWS management account:

```bash
cd platform-aws-core-bootstrap
npm install
npx cdk deploy
```

The deployment will output role ARNs like:
```
✓ CoreBootstrapStack

Outputs:
CoreBootstrapStackGitHubOIDCOIDCProviderArn = arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com
CoreBootstrapStackGitHubRolesRoleArnplatform-aws-lza-config = arn:aws:iam::ACCOUNT:role/github-MyOrg-platform-aws-lza-config
```

### Step 2: Store Role ARNs in GitHub

For each repository that will deploy to AWS, add the role ARN as an Actions secret:

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add a secret with:
   - **Name**: `AWS_ROLE_TO_ASSUME`
   - **Value**: The role ARN (e.g., `arn:aws:iam::ACCOUNT:role/github-MyOrg-platform-aws-lza-config`)

### Step 3: Update GitHub Actions Workflows

In your repository's GitHub Actions workflow, use the OIDC authentication:

```yaml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1

      - name: Deploy your stack
        run: |
          npx cdk deploy
          # or your deployment command
```

## Repository-Specific Configuration

Each repository that needs AWS access requires:

1. **Role ARN** stored as `AWS_ROLE_TO_ASSUME` secret
2. **Permissions** declared in workflow: `id-token: write`
3. **aws-actions/configure-aws-credentials** step with the role ARN

## Adding New Repositories

If you need to add a new repository with OIDC access:

1. Update `bin/app.ts` in this repository to include the new repository in the `repositories` array
2. Deploy the bootstrap stack: `npx cdk deploy`
3. Copy the new role ARN from the deployment output
4. Add the role ARN as a secret in the new repository

Example update to `bin/app.ts`:

```typescript
const repositories = [
  // ... existing repositories
  {
    owner: 'MyOrg',
    name: 'my-new-repository',
    environments: ['prod'],
  },
];
```

## Customizing Role Permissions

By default, roles have minimal permissions (only permission to assume other `github-*` roles). To add specific permissions:

1. Edit `lib/github-roles-stack.ts`
2. Add IAM policies to the role after it's created:

```typescript
role.addInlinePolicy(
  new iam.Policy(this, `S3Access-${repo.name}`, {
    statements: [
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:*'],
        resources: [`arn:aws:s3:::my-bucket/*`],
      }),
    ],
  })
);
```

3. Re-deploy: `npx cdk deploy`

## Troubleshooting

### "No OpenIDConnect provider found in your account"

If you see this error in GitHub Actions:

```
Could not assume role with OIDC: No OpenIDConnect provider found in your account
```

**Solution**: Deploy the bootstrap stack in your AWS account first.

### "Access Denied when assuming role"

Check that:
1. The role ARN in GitHub secret matches the actual role ARN (check CloudFormation outputs)
2. The repository name in the secret matches the role in AWS
3. The workflow has `permissions: id-token: write`

### "Role not found"

If the role doesn't exist:
1. Verify the repository is listed in `bin/app.ts` in the bootstrap stack
2. Re-deploy the bootstrap stack: `npx cdk deploy`
3. Retrieve the new role ARN from CloudFormation outputs

## Security Considerations

### OIDC Trust Policy

The roles are scoped to specific GitHub repositories using the `repo:OWNER/REPO:*` condition. This means:

- Only GitHub Actions from that specific repository can assume the role
- Different branches and environments can all assume the role
- External workflows cannot assume the role

### Least Privilege

Default roles only allow:
- `sts:AssumeRole` on other `github-*` roles

Add specific permissions only as needed for your deployment.

### Token Audience and Issuer

The OIDC configuration validates:
- **Issuer**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Subject**: `repo:MyOrg/REPOSITORY_NAME:*`

This prevents tokens from other sources from being misused.

## References

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
