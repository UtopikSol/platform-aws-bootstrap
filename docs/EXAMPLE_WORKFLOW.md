# Example GitHub Actions Workflow for OIDC

This directory contains an example GitHub Actions workflow demonstrating how to use the OIDC integration for AWS deployments.

## Quick Start

1. **Copy the workflow** to your repository:
   ```bash
   mkdir -p .github/workflows
   cp example-deploy.yml .github/workflows/deploy.yml
   ```

2. **Add the AWS role secret** to your repository:
   - Go to Settings → Secrets and variables → Actions
   - Create `AWS_ROLE_TO_ASSUME` with the role ARN from the bootstrap stack output

3. **Customize** the workflow for your needs

## Workflow Components

### Permissions

```yaml
permissions:
  id-token: write
  contents: read
```

The `id-token: write` permission is **required** for OIDC to work. It allows the workflow to request an ID token from GitHub.

### AWS Credentials Configuration

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
   mkdir -p .github/workflows
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-east-1
```

This step:
- Requests an OIDC token from GitHub
- Calls AWS STS AssumeRoleWithWebIdentity with the token
- Receives temporary AWS credentials
- Sets them as environment variables for subsequent steps

### Using AWS CLI/SDK

After the credentials configuration step, AWS CLI and SDKs are automatically authenticated:

```yaml
- name: Deploy with AWS CLI
  run: |
    aws s3 ls
    aws sts get-caller-identity
    # AWS credentials are automatically used
```

## Examples

### CDK Deployment

```yaml
- name: Install CDK
  run: npm install -g aws-cdk

- name: Deploy CDK Stack
  run: npx cdk deploy --require-approval=never
```

### CloudFormation Deployment

```yaml
- name: Deploy CloudFormation
  run: |
    aws cloudformation deploy \
      --template-file template.yaml \
      --stack-name my-stack
```

### Terraform Deployment

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v2

- name: Terraform Apply
  run: terraform apply -auto-approve
```

### Lambda Deployment

```yaml
- name: Deploy Lambda
  run: |
    aws lambda update-function-code \
      --function-name my-function \
      --s3-bucket my-bucket \
      --s3-key my-function.zip
```

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [AWS STS AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
