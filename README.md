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
│   ├── github-roles/              # Repository roles module
│   │   ├── main.tf                # Role definitions and policies
│   │   ├── variables.tf            # Module input variables
│   │   └── outputs.tf              # Module outputs
│   └── github-secrets/            # GitHub secrets and variables module
│       ├── main.tf                # Secrets/variables management
│       ├── variables.tf            # Module input variables
│       └── outputs.tf              # Module outputs
├── main.tf                        # Root module configuration
├── variables.tf                   # Root module variables
├── outputs.tf                     # Root module outputs
├── terraform.tfvars.example       # Example terraform variables
├── backend.hcl.example            # Example backend configuration
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

The module supports five permission levels for GitHub repositories:

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

### `network`
Network infrastructure management (VPC, subnets, routing, Route53)
- VPC and subnet creation/management
- Security group and network ACL operations
- Internet Gateway, NAT Gateway, VPN Gateway management
- VPC peering and endpoints
- Route53 hosted zone management
- **Limited IAM access for network-specific roles**
- Use for: Network infrastructure repos

### `read-only`
Read-only access for monitoring and reporting
- CloudWatch metrics and alarms
- CloudWatch Logs access
- Describe operations (EC2, RDS, S3, CloudFormation)
- Use for: Monitoring, reporting, analysis repos

## Deployment

### Initialize Terraform

```bash
terraform init -backend-config=backend.hcl
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

### Repository Configuration (terraform.tfvars)

Define your repositories in the `terraform.tfvars` file. Example structure:

```hcl
aws_region  = "us-east-1"
github_org  = "YourGitHubOrg"
github_token = ""

repositories = [
  {
    name        = "repo-name"
    permissions = "deploy"
    environments = [
      {
        name = "prod"
        secrets = [
          {
            name  = "AWS_ACCOUNT_ID"
            value = "123456789012"
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

tags = {
  Project   = "GitHub-Bootstrap"
  ManagedBy = "Terraform"
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
1. Repository name matches exactly in `terraform.tfvars`
2. GitHub organization matches `github_org` variable
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

Edit `terraform.tfvars` to add, remove, or modify repositories:

```bash
# Review planned changes
terraform plan

# Apply when changes look correct
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

## Getting Started

### Prerequisites Setup

1. **Configure AWS Credentials:**
   ```bash
   aws configure
   ```

2. **Copy example configuration:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   cp backend.hcl.example backend.hcl
   ```

3. **Edit `terraform.tfvars`** with your GitHub organization and repositories

### First Deployment

The first deployment must be run manually (chicken-and-egg: the OIDC role doesn't exist until after the first apply).

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

This will create:
- ✓ GitHub OIDC provider in AWS
- ✓ Repository-specific IAM roles
- ✓ GitHub environment secrets and variables
- ✓ SSM Parameter Store exports

### GitHub Token Configuration

The GitHub provider requires a token with `admin:org` scope. Provide it via:

**Option 1: Environment Variable (Recommended)**
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
terraform apply
```

**Option 2: Terraform Variable**
```hcl
# In terraform.tfvars
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**Option 3: GitHub Actions (Automatic)**
GitHub Actions automatically provides `GITHUB_TOKEN`.

## Managing Repositories

### Adding a Repository

Edit `terraform.tfvars` and add to the `repositories` list:

```hcl
repositories = [
  {
    name        = "my-new-repo"
    permissions = "deploy"
    environments = [
      {
        name = "prod"
        secrets = [
          {
            name  = "AWS_ACCOUNT_ID"
            value = "123456789012"
          }
        ]
      }
    ]
  }
]
```

Then apply:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Changing Permissions

Edit the `permissions` field in `terraform.tfvars` and apply:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Removing a Repository

Remove the repository from `terraform.tfvars` and apply:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## Role Details

### Role Naming

Roles follow the naming convention:
```
github-{github_org}-{repository_name}
```

Example: `github-MyOrg-my-repo`

### Assuming Roles in GitHub Actions

Use the `aws-actions/configure-aws-credentials` action:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
    aws-region: us-east-1
```

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

See LICENSE file for details.