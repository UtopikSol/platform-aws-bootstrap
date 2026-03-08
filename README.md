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

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Node.js 18+ and npm
- GitHub CLI (`gh`) for setting organization secrets
- Personal GitHub account with organization owner role (for setting secrets)

## Quick Start

### Development Environment

This project includes a `.devcontainer` configuration for VS Code. To use it:

1. Install [VS Code Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open the workspace in VS Code
3. Click "Reopen in Container" when prompted
4. All dependencies will be automatically installed

### Initial Setup (First Time Only)

#### 1. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID and Secret Access Key
```

#### 2. Update repositories.json

Edit [repositories.json](repositories.json) with your repositories and desired permission levels:

```json
{
  "githubOwner": "UtopikSol",
  "repositories": [
    {
      "name": "platform-aws-core-bootstrap",
      "permissions": "bootstrap"
    },
    {
      "name": "app-api",
      "permissions": "deploy"
    }
  ]
}
```

**Permission Levels:**
- `bootstrap` - Infrastructure/bootstrap management (create roles, OIDC providers)
- `full` - All AWS permissions (IAM, CloudFormation, S3, etc.)
- `deploy` - Application deployment (CloudFormation, S3, no IAM creation)
- `read-only` - Monitor and report (CloudWatch, Logs, no modifications)

#### 3. Run Bootstrap Script

```bash
./bootstrap.sh
```

This script will:
- ✓ Verify AWS credentials
- ✓ Bootstrap the AWS environment (CDK Toolkit)
- ✓ Install dependencies
- ✓ Deploy the bootstrap stack
- ✓ Create GitHub OIDC provider and IAM roles

#### 4. Set Organization Secret

Authenticate with GitHub and set the organization secret:

```bash
gh auth login
# Authenticate with your GitHub account (requires org owner role)

./set-github-secrets.sh 271003693931
# Replace with your actual AWS Account ID
```

This sets `AWS_ACCOUNT_ID` as an organization secret, available to all repositories.

### Automated Updates (GitHub Actions)

After initial setup, updates are fully automated:

1. **Modify repositories.json** - Add/remove repositories or change permissions
2. **Create a Pull Request** - GitHub Actions automatically validates with PR validation workflow
3. **Merge to main** - Deploy workflow automatically runs when merged
   - Creates/updates IAM roles for all repositories
   - Displays stack outputs



## Configuration

### Repository Configuration

Edit [repositories.json](repositories.json) to manage repositories and their permissions:

```json
{
  "githubOwner": "UtopikSol",
  "repositories": [
    {
      "name": "repository-name",
      "permissions": "deploy"
    }
  ]
}
```

### Permission Levels Reference

| Level | Use Case | Permissions |
|-------|----------|---|
| `bootstrap` | Infrastructure management, bootstrap repos | Full IAM, CloudFormation, S3, OIDC provider management |
| `full` | Comprehensive infrastructure repos | All AWS permissions |
| `deploy` | Application deployment repos | CloudFormation, S3, can pass existing IAM roles |
| `read-only` | Monitoring, reporting, analysis | CloudWatch, Logs, describe operations only |

## Understanding the Architecture

### How It Works

1. **GitHub OIDC Provider** - AWS trusts GitHub's OpenID provider
2. **Repository-Specific Roles** - Each repo gets its own IAM role
3. **Dynamic Role ARN Computation** - Workflows compute role ARN from repo name and account ID
4. **No Long-Lived Credentials** - Uses short-lived OIDC tokens

### Role Naming Convention

```
arn:aws:iam::ACCOUNT_ID:role/github-OWNER-REPO_NAME
```

Example: `arn:aws:iam::271003693931:role/github-UtopikSol-platform-aws-core-bootstrap`

## Project Structure

```
├── bin/
│   └── app.ts                    # CDK app entry point
├── lib/
│   ├── github-oidc-stack.ts      # OIDC provider configuration
│   ├── github-roles-stack.ts     # Repository-specific role definitions
│   └── core-bootstrap-stack.ts   # Stack composition and orchestration
├── .devcontainer/
│   └── devcontainer.json         # Dev container configuration
├── .github/workflows/
│   ├── deploy-core-bootstrap.yml # Automated deployment workflow
│   └── pr-validation.yml         # PR validation checks
├── .gitattributes
├── bootstrap.sh                  # One-step bootstrap script
├── set-github-secrets.sh         # Sets organization secrets
├── package.json                  # Dependencies
├── tsconfig.json                 # TypeScript configuration
└── cdk.json                      # CDK configuration
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

## Troubleshooting

### AWS Credentials Not Found

**Error:** `Unable to locate credentials. You can configure credentials by running 'aws login'.`

**Solution:** Configure AWS credentials using:
```bash
aws configure
```

### Bootstrap Failed - SSM Parameter Not Found

**Error:** `SSM parameter /cdk-bootstrap/hnb659fds/version not found`

**Solution:** This means AWS CDK hasn't bootstrapped the environment yet. Run:
```bash
./bootstrap.sh
```

It handles all bootstrap steps automatically.

### GitHub Secret Not Set

**Error:** `AWS_ACCOUNT_ID secret not set`

**Solution:** Set the organization secret:
```bash
gh auth login
./set-github-secrets.sh 271003693931
```

### Permissions Denied on Secret Setup

**Error:** `HTTP 403: Resource not accessible`

**Solution:** Your GitHub account needs to be an organization owner. Contact your organization admin.

## Common Workflows

### Add a New Repository

1. Edit `repositories.json`:
   ```json
   {
     "name": "my-new-repo",
     "permissions": "deploy"
   }
   ```

2. Commit and push to main:
   ```bash
   git add repositories.json
   git commit -m "Add my-new-repo"
   git push origin main
   ```

3. GitHub Actions automatically:
   - Creates the IAM role `github-UtopikSol-my-new-repo`
   - Makes it assume-able by the `my-new-repo` repository

### Change a Repository's Permissions

1. Edit `repositories.json` and change the `permissions` field
2. Commit and push - GitHub Actions updates the role permissions automatically

### Deploy Manually Without GitHub Actions

```bash
# Update repositories.json first
nano repositories.json

# Then deploy
npm run build
npx cdk deploy --require-approval=never
```

### Verify Role Creation

```bash
AWS_REGION=ca-central-1 aws iam list-roles | grep github-
```

## Security Best Practices

1. **Least Privilege** - Assign only the minimum permissions each repo needs
2. **Audit Changes** - Review all `repositories.json` changes before merge
3. **Monitor Usage** - Check CloudTrail for OIDC role usage
4. **Rotate Secrets** - Use short-lived OIDC tokens (15 minutes default)
5. **Limit Scope** - Roles are scoped to specific repositories via OIDC conditions

## Development

### Building the Project

```bash
npm run build
```

### Type Checking

```bash
npm run build
```

### Synthesizing CDK

```bash
npx cdk synth
```

### Running Tests

```bash
npm test
```

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review [AWS CDK documentation](https://docs.aws.amazon.com/cdk/)
3. Check [GitHub OIDC documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
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