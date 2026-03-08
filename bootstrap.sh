#!/bin/bash

# AWS CDK Bootstrap Script
# This script bootstraps the AWS environment for CDK deployments
# Run this ONCE before your first 'cdk deploy'

# Don't exit on error immediately - we want to handle errors gracefully
set +e

echo "========================================"
echo "AWS CDK Bootstrap Script"
echo "========================================"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    echo "   See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials are not configured."
    echo "   Please configure your AWS credentials using 'aws configure'"
    exit 1
fi

# Get AWS account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# Default to ca-central-1, can be overridden with AWS_REGION or AWS_DEFAULT_REGION env var
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-ca-central-1}}

echo "✓ AWS Credentials Found"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo ""
echo "Note: Deploying to $REGION"
echo ""

# Check if Node.js and CDK are available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed."
    exit 1
fi

echo "✓ Node.js is installed"
echo ""

# Install CDK CLI if not already installed globally
if ! command -v cdk &> /dev/null; then
    echo "📦 Installing AWS CDK CLI globally..."
    npm install -g aws-cdk
    echo "✓ AWS CDK CLI installed"
else
    echo "✓ AWS CDK CLI is already installed"
fi

echo ""
echo "========================================"
echo "Bootstrapping AWS Environment"
echo "========================================"
echo "Running: cdk bootstrap aws://$ACCOUNT_ID/$REGION"
echo ""

# Run cdk bootstrap with error handling
cdk bootstrap aws://$ACCOUNT_ID/$REGION
BOOTSTRAP_EXIT_CODE=$?

if [ $BOOTSTRAP_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠️  Bootstrap returned an error code"
    echo "   This might be because bootstrap has already been completed."
    echo "   Proceeding with deployment..."
else
    echo ""
    echo "✓ Bootstrap complete!"
    echo ""
fi

# Verify bootstrap was successful - the CDK toolkit should exist
echo "Verifying bootstrap..."
sleep 5  # Wait a moment for AWS to propagate

# Check if the CDKToolkit stack exists
if aws cloudformation describe-stacks --stack-name CDKToolkit --region "$REGION" &> /dev/null; then
    echo "✓ CDKToolkit stack verified in $REGION"
else
    echo "⚠️  CDKToolkit stack not found. Waiting and retrying..."
    sleep 10
    if ! aws cloudformation describe-stacks --stack-name CDKToolkit --region "$REGION" &> /dev/null; then
        echo "❌ CDKToolkit stack verification failed."
        echo "   The bootstrap stack may not have deployed correctly."
        echo "   Try running: cdk bootstrap aws://$ACCOUNT_ID/$REGION"
        exit 1
    fi
    echo "✓ CDKToolkit stack verified in $REGION"
fi

echo ""
echo "========================================"
echo "Configuring S3 Bucket Permissions"
echo "========================================"
ASSETS_BUCKET="cdk-hnb659fds-assets-$ACCOUNT_ID-$REGION"

# Create a temporary policy file
POLICY_FILE=$(mktemp)

# Get the existing bucket policy or create a new one
EXISTING_POLICY=$(aws s3api get-bucket-policy --bucket "$ASSETS_BUCKET" --region "$REGION" 2>/dev/null)

if [ $? -eq 0 ]; then
    # Policy exists, we'll add to it
    echo "$EXISTING_POLICY" > "$POLICY_FILE"
else
    # No policy exists, create a new one
    cat > "$POLICY_FILE" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": []
}
EOF
fi

# Add S3 access statement for GitHub roles (will be created after deployment)
# This statement uses a wildcard for all github-* roles in the account
cat >> "$POLICY_FILE.new" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubRoleCDKAssetAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ACCOUNT_ID:role/github-*"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::$ASSETS_BUCKET",
        "arn:aws:s3:::$ASSETS_BUCKET/*"
      ]
    }
  ]
}
EOF

# Apply the new policy
aws s3api put-bucket-policy --bucket "$ASSETS_BUCKET" --policy file://"$POLICY_FILE.new" --region "$REGION"
if [ $? -eq 0 ]; then
    echo "✓ S3 bucket policy updated for GitHub roles"
else
    echo "⚠️  Failed to update bucket policy (may already be set)"
fi

# Cleanup temp files
rm -f "$POLICY_FILE" "$POLICY_FILE.new"
echo ""

echo "========================================"
echo "Installing Project Dependencies"
echo "========================================"
npm install
if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo "✓ Dependencies installed"
echo ""

echo "========================================"
echo "Building TypeScript"
echo "========================================"
npm run build
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi
echo "✓ Build complete"
echo ""

echo "========================================"
echo "Deploying CDK Stack"
echo "========================================"
export CDK_DEFAULT_ACCOUNT=$ACCOUNT_ID
export CDK_DEFAULT_REGION=$REGION
npx cdk deploy --require-approval=never
DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌ Deployment failed. Please review the errors above."
    exit 1
fi

echo ""
echo "========================================"
echo "✓ Deployment Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Make changes to repositories.json as needed"
echo "  2. Push to main branch"
echo "  3. GitHub Actions will automatically deploy future changes"
echo ""
