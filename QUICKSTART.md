# Quick Start Guide

Get up and running with GitHub OIDC and Terraform in 5 minutes.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials
- GitHub CLI (`gh`) installed and authenticated (optional, for setting secrets)

## Installation

### 1. Configure your settings
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region = "us-east-1"
environment = "prod"

repositories = [
  {
    owner       = "YourGitHubOrg"      # Your GitHub organization
    name        = "your-repo-name"     # Repository name
    permissions = "deploy"             # or: bootstrap, full, read-only
  },
]
```

### 2. Initialize Terraform
```bash
terraform init
```

Or use the provided bootstrap script:
```bash
./bootstrap.sh
```

### 3. Review and apply
```bash
terraform plan
terraform apply
```

### 4. (Optional) Set GitHub Secrets
If you want to store AWS_ACCOUNT_ID as an organization secret:
```bash
./set-github-secrets.sh YOUR_AWS_ACCOUNT_ID
```

## In Your GitHub Repository

Add this to `.github/workflows/deploy.yml`:

```yaml
name: Deploy with Terraform

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v2
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
          aws-region: us-east-1
      
      - name: Deploy
        run: |
          terraform init
          terraform apply -auto-approve
```

## What Gets Created

✅ GitHub OIDC Provider (one time, shared)
✅ IAM Roles (one per repository)
✅ Trust policies (repository-scoped)
✅ Inline policies (based on permission level)

## Outputs

After `terraform apply`, you'll see:

```
oidc_provider_arn = "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
role_arns = {
  "your-repo-name" = "arn:aws:iam::123456789:role/github-YourOrg-your-repo-name"
}
```

## Next Steps

- Read [README.md](./README.md) for comprehensive documentation
- Check [docs/EXAMPLE_WORKFLOW.md](./docs/EXAMPLE_WORKFLOW.md) for more workflow examples
- Review [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) if migrating from CDK

## Common Commands

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# See what will change
terraform plan

# Apply changes
terraform apply

# Get outputs
terraform output

# Destroy everything
terraform destroy
```

## Troubleshooting

### "Role not found" in GitHub Actions
1. Verify role was created: `aws iam list-roles | grep github`
2. Check repository name matches exactly (case-sensitive)
3. Ensure `role-to-assume` matches your repository

### "Permission denied" in workflows
1. Check permission level in `terraform.tfvars`
2. Verify your AWS resources match approved resources
3. See detailed permissions in [README.md](./README.md#permissions-levels)

### Need to add/remove repositories
1. Edit `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply`

## Support

- Main documentation: [README.md](./README.md)
- Example workflows: [docs/EXAMPLE_WORKFLOW.md](./docs/EXAMPLE_WORKFLOW.md)
- Migration from CDK: [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
