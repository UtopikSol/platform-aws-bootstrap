# platform-aws-core-bootstrap

AWS CDK project for setting up GitHub OpenID Connect (OIDC) integration and IAM roles for secure, credential-free deployments from GitHub Actions.

## Overview

This repository establishes the foundational AWS infrastructure required for GitHub Actions workflows to securely assume AWS IAM roles using OpenID Connect (OIDC) authentication. This eliminates the need for long-lived AWS access keys and secrets stored in GitHub.

### Key Components

- **GitHub OIDC Provider**: An AWS OpenID Connect Provider configured to trust GitHub's token.actions.githubusercontent.com
- **IAM Roles**: Repository-specific roles that each GitHub repository can assume with appropriate conditions
- **Role Outputs**: CloudFormation exports for downstream repositories to reference

## Architecture

```
GitHub Actions Workflow
        ↓
    JWT Token from GitHub
        ↓
    AWS STS AssumeRoleWithWebIdentity
        ↓
    GitHub OIDC Provider (validates token)
        ↓
    Repository-specific IAM Role
        ↓
    AWS Permissions
```

## Project Structure

```
├── bin/
│   └── app.ts                    # CDK app entry point
├── lib/
│   ├── github-oidc-stack.ts      # OIDC provider configuration
│   ├── github-roles-stack.ts     # Repository-specific role definitions
│   └── core-bootstrap-stack.ts   # Stack composition and orchestration
├── package.json                  # Dependencies
├── tsconfig.json                 # TypeScript configuration
└── cdk.json                      # CDK configuration
```

## Prerequisites

- AWS Account (this repo will set up the GitHub OIDC provider and IAM roles)
- AWS CLI configured with credentials to deploy CDK
- Node.js 18+ and npm
- AWS CDK CLI (`npm install -g aws-cdk`)

## Configuration

### Repository Configuration

The list of repositories is managed in [repositories.json](repositories.json). This JSON file contains:

- `githubOwner`: Default GitHub organization name
- `repositories`: Array of repository configurations

#### Editing repositories.json

To add, remove, or modify repositories, edit `repositories.json`:

```json
{
  "githubOwner": "your-org",
  "repositories": [
    {
      "name": "repository-name",
      "environments": ["prod"]
    }
  ]
}
```

#### Environment Variable Override

You can override the GitHub organization without editing the file:

```bash
export GITHUB_ORG=my-org
npx cdk deploy
```

## Setup Instructions

### Initial Bootstrap (Manual Deployment)

The first deployment must be done manually since the OIDC roles don't exist yet.

#### 1. Update Organization Name

Edit [repositories.json](repositories.json) and set your GitHub organization:

```json
{
  "githubOwner": "your-actual-org"
}
```

#### 2. Install Dependencies

```bash
npm install
```

#### 3. Build TypeScript

```bash
npm run build
```

#### 4. Review the Stack

```bash
npx cdk synth
```

#### 5. Deploy Bootstrap Stack (Manual)

Configure AWS credentials and deploy:

```bash
# Configure with your AWS management account credentials
aws configure

# Deploy the bootstrap stack
npx cdk deploy
```

The CDK will create:
1. GitHub OIDC Provider
2. IAM roles for each repository (including one for this bootstrap repo)

#### 6. Set Secret in This Repository

After bootstrap deployment completes, the role ARN for this repo is displayed. Store it as a secret:

1. Go to this repo → Settings → Secrets and variables → Actions
2. Create secret `AWS_ROLE_TO_ASSUME` with the bootstrap role ARN
   - Format: `arn:aws:iam::ACCOUNT:role/github-your-org-platform-aws-core-bootstrap`

#### 7. Update Bootstrap Role Permissions

Add CDK deployment permissions to the bootstrap role in [lib/github-roles-stack.ts](lib/github-roles-stack.ts):

```typescript
// Find the platform-aws-core-bootstrap role and add permissions
if (repo.name === 'platform-aws-core-bootstrap') {
  role.addInlinePolicy(
    new iam.Policy(this, `BootstrapDeployPolicy`, {
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'cloudformation:*',
            'iam:*',
            'sts:*',
          ],
          resources: ['*'],
        }),
      ],
    })
  );
}
```

Then redeploy: `npx cdk deploy`

### Future Updates (GitHub Actions Automated)

After initial setup, future updates are automated:

1. **Add new repositories**: Update [repositories.json](repositories.json)
2. **Push to main branch**: GitHub Actions automatically:
   - Deploys CDK changes
   - Creates roles for new repositories
   - Sets `AWS_ROLE_TO_ASSUME` secrets in all repositories (new and existing)

No manual steps needed! The workflow:
- Uses this repo's OIDC role to deploy
- Runs the secret-setting script automatically after CDK deploy
- Sets secrets in all repos defined in `repositories.json`

For manual deployments:
```bash
npx cdk deploy
./set-github-secrets.sh your-org 123456789012
```

## Managed Repositories

This bootstrap configures OIDC roles for the following 23 repositories:

### AWS Platform Services
- `platform-aws-lza-config`
- `platform-aws-aft-account-requests`
- `platform-aws-aft-account-customizations`
- `platform-aws-aft-provisioning`
- `platform-aws-tf-modules`

### AWS Infrastructure
- `infra-aws-shared-network`
- `infra-aws-eks-platform`
- `infra-aws-app-erp`
- `infra-aws-app-crm`

### Azure Platform Services
- `platform-azure-landingzone`
- `platform-azure-policy`
- `platform-azure-management`
- `platform-azure-tf-modules`

### Azure Infrastructure
- `infra-azure-shared-network`
- `infra-azure-aks-platform`
- `infra-azure-app-erp`

### Tools & Automation
- `tools-ci-templates`
- `tools-terraform-linters`
- `tools-security-policies`
- `automation-cloud-reports`

### Applications
- `app-identity-service`
- `app-erp-api`
- `app-erp-frontend`

## Role Permissions

Each repository has a dedicated IAM role created by this bootstrap. The role:

- **Only that repository can assume** (scoped via OIDC to `repo:your-org/repo-name:*`)
- **Has no default permissions** (except assuming other `github-*` roles)

### Adding Permissions to a Role

You must customize each role with the specific permissions it needs. For example:

**For a CDK deployment repo:**
```typescript
role.addInlinePolicy(
  new iam.Policy(this, `CDKDeployPolicy-${repo.name}`, {
    statements: [
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'cloudformation:*',
          'iam:PassRole',
          's3:GetObject',
          's3:PutObject',
        ],
        resources: ['*'],
      }),
    ],
  })
);
```

**For a Terraform repo:**
```typescript
role.addInlinePolicy(
  new iam.Policy(this, `TerraformPolicy-${repo.name}`, {
    statements: [
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['ec2:*', 'rds:*', 'vpc:*'],
        resources: ['*'],
      }),
    ],
  })
);
```

Edit the role definitions in [lib/github-roles-stack.ts](lib/github-roles-stack.ts) to add permissions specific to each repository.

## GitHub OIDC Trust Policy

The roles trust the GitHub OIDC provider with the following conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/REPOSITORY_NAME:*"
        }
      }
    }
  ]
}
```

## CDK Commands

```bash
# Build TypeScript
npm run build

# Watch TypeScript for changes
npm run watch

# Synthesize the CDK app (generates CloudFormation)
npm run synth

# Deploy to AWS
npm run deploy

# Destroy the stack
npm run destroy

# Compare with deployed version
npm run cdk -- diff
```



## References

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/v2/guide/)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [GitHub OIDC AWS Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

## License

See LICENSE file for details.