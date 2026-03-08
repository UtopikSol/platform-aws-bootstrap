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
