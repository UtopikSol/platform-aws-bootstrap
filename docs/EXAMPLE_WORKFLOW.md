# Example GitHub Actions Workflow for OIDC

This directory contains example GitHub Actions workflows demonstrating how to use the OIDC integration for AWS deployments with Terraform.

## Quick Start

1. **Copy the workflow** to your repository:
   ```bash
   mkdir -p .github/workflows
   cp docs/example-deploy.yml .github/workflows/deploy.yml
   ```

2. **Add environment secret** to your repository:
   - Go to Settings → Secrets and variables → Actions
   - Create repository or organization secret `AWS_ACCOUNT_ID` with your AWS Account ID

3. **Verify permissions:**
   - Go to Settings → Actions → General → Workflow permissions
   - Enable "Read and write permissions"
   - Enable "Allow GitHub Actions to create and approve pull requests"

## Workflow Components

### Permissions Block (Required)

```yaml
permissions:
  id-token: write    # Required! Allows JWT token request
  contents: read     # Read repository contents
```

The `id-token: write` permission is **critical** for OIDC. It allows the workflow to request a JWT token from GitHub.

### AWS Credentials Configuration (Key Step)

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
    aws-region: us-east-1
```

This step:
1. Requests a JWT token from GitHub (uses `id-token: write` permission)
2. Calls AWS STS `AssumeRoleWithWebIdentity` with the JWT token
3. Validates the token against the GitHub OIDC provider
4. Validates repository name and owner in the trust policy
5. Returns temporary AWS credentials
6. Sets them as environment variables for subsequent steps

### Using AWS Credentials

After the credentials configuration step, AWS CLI and SDKs are automatically authenticated:

```yaml
- name: Verify AWS Access
  run: |
    aws sts get-caller-identity
    aws ec2 describe-instances
```

## Example Workflows

### Terraform Deployment

The example workflow included with this repository deploys infrastructure using Terraform:

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
        with:
          terraform_version: latest
      
      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
          aws-region: us-east-1
      
      - name: Deploy Infrastructure
        run: |
          terraform init
          terraform plan
          terraform apply -auto-approve
```

### CloudFormation Deployment

```yaml
name: Deploy with CloudFormation

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
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
          aws-region: us-east-1
      
      - name: Deploy Stack
        run: |
          aws cloudformation deploy \
            --template-file template.yaml \
            --stack-name my-stack \
            --no-fail-on-empty-changeset
```

### Lambda Function Deployment

```yaml
name: Deploy Lambda

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
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
          aws-region: us-east-1
      
      - name: Package and Deploy
        run: |
          pip install -r requirements.txt -t package/
          cd package && zip -r ../function.zip . && cd ..
          zip function.zip lambda_function.py
          
          aws lambda update-function-code \
            --function-name my-function \
            --zip-file fileb://function.zip
```

### Multi-Environment Deployment

```yaml
name: Multi-Env Deploy

on:
  push:
    branches:
      - main
      - develop

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    environment:
      name: ${{ matrix.environment }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets[format('{0}_AWS_ACCOUNT_ID', matrix.environment)] }}:role/github-${{ github.repository_owner }}-${{ github.event.repository.name }}
          aws-region: us-east-1
      
      - name: Deploy to ${{ matrix.environment }}
        run: |
          terraform apply -var="environment=${{ matrix.environment }}" -auto-approve
```

## Troubleshooting

### Error: "Role not found"

**Problem:** `InvalidClientTokenId` or role doesn't exist

**Solution:**
1. Verify role name matches: `github-OWNER-REPO-NAME`
2. Check AWS account ID is correct
3. Ensure Terraform bootstrap has been applied to create the role

### Error: "Not authorized to perform"

**Problem:** Insufficient role permissions

**Solution:**
1. Verify permission level in `repositories.json`
2. Check role inline policy is attached
3. Review role permissions match your workflow needs

### Error: "AssumeRoleUnauthorizedOperation"

**Problem:** Trust policy doesn't match token claims

**Solution:**
1. Verify repository owner name (case-sensitive)
2. Verify repository name (case-sensitive)
3. Check the token subject claim matches `repo:OWNER/REPO:*`

### "id-token: write" permission missing

**Problem:** Workflow cannot request OIDC token

**Solution:**
Add to workflow:
```yaml
permissions:
  id-token: write
  contents: read
```

## Security Best Practices

1. **Least Privilege**: Use the minimum permission level needed
   - `read-only` for monitoring/reporting
   - `deploy` for application deployments
   - `bootstrap` only for infrastructure repositories

2. **Environment Secrets**: Store AWS account IDs as secrets, not in code

3. **Branch Protection**: Require reviews before merging to protected branches

4. **Audit**: Review GitHub Actions logs and AWS CloudTrail to audit deployments

5. **Token Validation**: GitHub's OIDC tokens are short-lived and cannot be reused

6. **Role Restrictions**: Roles are restricted by:
   - GitHub organization (OIDC provider)
   - Repository name and owner (trust policy)
   - OIDC token audience (sts.amazonaws.com)

## Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS Actions: Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform in GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [Security Hardening Guide](https://docs.github.com/en/actions/security-guides)

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [AWS STS AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
