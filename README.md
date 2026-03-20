# platform-aws-bootstrap

Terraform infrastructure for setting up GitHub OpenID Connect (OIDC) integration and IAM roles for secure, credential-free deployments from GitHub Actions.

## Overview

This repository establishes the foundational AWS infrastructure required for GitHub Actions workflows to securely assume AWS IAM roles using OpenID Connect (OIDC) authentication. This eliminates the need for long-lived AWS access keys and secrets stored in GitHub.

### Key Components

- **GitHub OIDC Provider**: An AWS OpenID Connect Provider configured to trust GitHub's token.actions.githubusercontent.com
- **IAM Roles**: Repository-specific roles that each GitHub repository can assume with appropriate conditions
- **Parameter Store Exports**: AWS Systems Manager Parameter Store values for downstream infrastructure references

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
├── modules/
│   ├── github-oidc/              # OIDC provider module
│   │   ├── main.tf               # OIDC provider configuration
│   │   ├── variables.tf           # Module input variables
│   │   └── outputs.tf             # Module outputs
│   └── github-roles/              # Repository roles module
│       ├── main.tf                # Role definitions and policies
│       ├── variables.tf            # Module input variables
│       └── outputs.tf              # Module outputs
├── main.tf                        # Root module configuration
├── variables.tf                   # Root module variables
├── outputs.tf                     # Root module outputs
├── terraform.tf                   # Terraform provider requirements
├── terraform.tfvars.example       # Example terraform variables
├── repositories.json              # Repository configuration
└── README.md                      # This file
```

## Prerequisites

- Terraform >= 1.5
- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- GitHub organization/account with repository access

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/UtopikSol/platform-aws-bootstrap.git
   cd platform-aws-bootstrap
   ```

2. **Create terraform variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars` with your configuration:**
   ```hcl
   aws_region = "us-east-1"
   environment = "prod"
   
   repositories = [
     {
       owner       = "YourGitHubOrg"
       name        = "your-repo-name"
       permissions = "deploy"
     },
   ]
   ```

## Permissions Levels

The module supports four permission levels for GitHub repositories:

### `bootstrap`
Infrastructure/bootstrap management (for infrastructure as code repositories)
- Role/OIDC provider management
- CloudFormation stack operations
- S3 artifact bucket access
- IAM role creation and management
- Use for: `platform-aws-bootstrap`, infrastructure automation repos

### `full`
All AWS permissions (comprehensive infrastructure management)
- Everything in `bootstrap` plus additional permissions
- Full IAM access without restrictions
- All CloudFormation operations
- Use for: Multi-service infrastructure management repos

### `deploy`
Application deployment (CloudFormation, S3, Lambda, RDS)
- CloudFormation stack operations
- S3 artifact bucket access
- Lambda function deployment
- RDS database operations
- **No IAM modifications allowed**
- Use for: Application deployment repos

### `read-only`
Read-only access for monitoring and reporting
- CloudWatch metrics and alarms
- CloudWatch Logs access
- Describe operations (EC2, RDS, S3, CloudFormation)
- Use for: Monitoring, reporting, analysis repos

## Deployment

### Initialize Terraform

```bash
terraform init
```

### Plan Deployment

```bash
terraform plan -out=tfplan
```

### Apply Configuration

```bash
terraform apply tfplan
```

### Destroy Resources

```bash
terraform destroy
```

## Configuration

### Repository Configuration (repositories.json)

Example structure:
```json
{
  "githubOwner": "UtopikSol",
  "repositories": [
    {
      "owner": "UtopikSol",
      "name": "my-infrastructure-repo",
      "permissions": "bootstrap",
      "environments": ["prod"]
    },
    {
      "owner": "UtopikSol",
      "name": "my-app-repo",
      "permissions": "deploy",
      "environments": ["dev", "staging", "prod"]
    }
  ]
}
```

### Terraform Variables (terraform.tfvars)

```hcl
aws_region = "us-east-1"
environment = "prod"

repositories = [
  {
    owner       = "YourOrg"
    name        = "repo-name"
    permissions = "deploy"
    environments = ["prod"]
  },
]

tags = {
  Team       = "Platform"
  CostCenter = "Engineering"
}
```

## Using OIDC Roles in GitHub Actions

### Example: Deploy with OIDC

Create a `.github/workflows/deploy.yml` file in your repository:

```yaml
name: Deploy with OIDC

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-YourOrg-repo-name
          aws-region: us-east-1
      
      - name: Deploy Application
        run: |
          # Your deployment commands here
          aws s3 cp app.zip s3://my-bucket/
```

### Example: Multi-Account Deployment

```yaml
name: Deploy to Multiple Accounts

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        account: [dev, prod]
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials (${{ matrix.account }})
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets[format('{0}_ACCOUNT_ID', matrix.account)] }}:role/github-YourOrg-repo-name
          aws-region: us-east-1
      
      - name: Deploy to ${{ matrix.account }}
        run: terraform apply -auto-approve -var="environment=${{ matrix.account }}"
```

## Outputs

After deployment, Terraform outputs the following:

```bash
oidc_provider_arn  = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
role_arns          = {
  "my-repo" = "arn:aws:iam::ACCOUNT_ID:role/github-YourOrg-my-repo"
}
role_names         = {
  "my-repo" = "github-YourOrg-my-repo"
}
ssm_parameters     = {...}
```

## State Management

By default, Terraform state is stored locally. For production use, configure remote state:

```hcl
# Uncomment in main.tf
backend "s3" {
  bucket         = "my-terraform-state"
  key            = "github-bootstrap/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

## Troubleshooting

### OIDC Provider Already Exists

If you encounter an error about the OIDC provider already existing:

```bash
# Import the existing provider
terraform import module.github_oidc.aws_iam_openid_connect_provider.github arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### Role Not Found in GitHub Actions

Verify:
1. Repository name matches exactly in `repositories.json`
2. GitHub organization matches `owner` field
3. IAM role exists: `aws iam get-role --role-name github-ORG-REPO`
4. OIDC provider is configured correctly

### Permission Denied Errors

Check the role permissions for your permission level and ensure the resources match your AWS resources.

## Module Outputs

### github-oidc module
- `oidc_provider_arn`: ARN of the GitHub OIDC provider
- `oidc_provider_url`: URL of the OIDC provider

### github-roles module
- `role_arns`: Map of repository names to role ARNs
- `role_names`: Map of repository names to role names

## Testing

### Validate Terraform

```bash
terraform validate
terraform fmt -recursive -check
```

### Plan Without Apply

```bash
terraform plan
```

### Check Specific Resource

```bash
terraform state list
terraform state show 'module.github_roles.aws_iam_role.github["my-repo"]'
```

## Security Considerations

1. **Least Privilege**: Use the most restrictive permission level needed
2. **Branch Protection**: Require reviews before merging to protected branches
3. **Environment Secrets**: Store AWS account IDs as GitHub organization secrets
4. **Regular Audits**: Review IAM roles and permissions regularly
5. **State Protection**: Use encrypted S3 backend with versioning
6. **MFA**: Enable MFA for AWS console access

## Maintenance

### Updating Repositories

Edit `repositories.json` and `terraform.tfvars`:

```bash
# Plan changes
terraform plan

# Review changes
# Apply when ready
terraform apply
```

### Rotating Credentials

The module uses OIDC tokens, which are short-lived and don't require rotation. However:

1. GitHub OIDC certificates rotate automatically
2. No manual credential management needed
3. AWS handles provider certificate updates

## Contributing

1. Create a feature branch
2. Make changes
3. Run `terraform validate` and `terraform fmt`
4. Create a pull request
5. After review, merge and deploy

## Documentation

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [Platform AWS Bootstrap Issues](https://github.com/UtopikSol/platform-aws-bootstrap/issues)
- Documentation: [EXAMPLE_WORKFLOW.md](./docs/EXAMPLE_WORKFLOW.md)
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
      "name": "platform-aws-bootstrap",
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

#### 3. GitHub Token Configuration

The GitHub token can be provided in multiple ways, depending on your environment:

**Option 1: Environment Variable (Recommended for CI/CD)**
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
terraform apply
```

**Option 2: Terraform Variable (For Codespaces)**
```hcl
# In terraform.tfvars
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**Option 3: GitHub Actions (Automatic)**
GitHub Actions automatically provides `GITHUB_TOKEN` - no configuration needed:

```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Note:** The token requires `admin:org` scope to manage organization-level resources.

#### 4. Deploy Terraform

```bash
terraform init
terraform plan
terraform apply
```

This will:
- ✓ Create GitHub OIDC provider in AWS
- ✓ Create repository-specific IAM roles
- ✓ Set up environment secrets and variables
- ✓ Configure GitHub Actions integration

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

Example: `arn:aws:iam::123456789012:role/github-UtopikSol-platform-aws-bootstrap`

## Project Structure

```
├── bin/
│   └── app.ts                    # CDK app entry point
├── lib/
│   ├── github-oidc-stack.ts      # OIDC provider configuration
│   ├── github-roles-stack.ts     # Repository-specific role definitions
│   └── bootstrap-stack.ts   # Stack composition and orchestration
├── .devcontainer/
│   └── devcontainer.json         # Dev container configuration
├── .github/workflows/
│   └── deploy-bootstrap.yml      # Automated deployment workflow
├── .gitattributes
├── main.tf                       # Main Terraform configuration
├── variables.tf                  # Terraform variables
├── outputs.tf                    # Terraform outputs
├── github-secrets.tf             # GitHub secrets management
├── terraform.tfvars.example      # Example Terraform variables
└── README.md                     # This file
```

## Managing Secrets and Variables

GitHub secrets and environment variables are managed entirely through Terraform:

### Organization Secrets
Organization-level secrets (e.g., `AWS_ACCOUNT_ID`) are available to all repositories:

```hcl
# Set in terraform.tfvars
aws_account_id = "111111111111"
```

### Environment Secrets and Variables
Specify secrets and variables per repository/environment in `terraform.tfvars`:

```hcl
repositories = [
  {
    owner       = "YourOrg"
    name        = "your-repo"
    permissions = "deploy"
    environments = [
      {
        name = "prod"
        secrets = [
          {
            name  = "AWS_ACCOUNT_ID"
            value = "111111111111"
          }
        ]
        variables = [
          {
            name  = "AWS_REGION"
            value = "us-east-1"
          }
        ]
      }
    ]
  }
]
```

Terraform will automatically create and manage these secrets across your repositories.

## Managed Repositories

Configure repositories and their permissions in `terraform.tfvars`. Terraform manages all OIDC roles and GitHub secrets automatically.

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
./set-github-secrets.sh 123456789012
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