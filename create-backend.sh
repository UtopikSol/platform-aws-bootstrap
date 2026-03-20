#!/bin/bash

# Script to create S3 bucket for Terraform backend and generate config/backend.hcl
# Automatically detects account ID and region from AWS SSO session
# Usage: ./create-backend.sh [account-id] [region]
# Example: ./create-backend.sh (auto-detect from SSO)
# Example: ./create-backend.sh 198252713378 ca-central-1 (override defaults)

set -e

# Parse arguments (optional - will auto-detect if not provided)
ACCOUNT_ID="${1:-}"
REGION="${2:-}"
BACKEND_HCL="${3:-$(dirname "${BASH_SOURCE[0]}")/backend.hcl}"
BUCKET_PREFIX="${4:-bootstrap}"

# Auto-detect Account ID from AWS SSO session if not provided
if [ -z "$ACCOUNT_ID" ]; then
    echo "Detecting AWS account ID from SSO session..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ -z "$ACCOUNT_ID" ]; then
        echo "Error: Could not detect account ID. Please ensure AWS credentials are configured."
        echo "Usage: ./create-backend.sh [account-id] [region] [backend-hcl] [bucket-prefix]"
        exit 1
    fi
    echo "✓ Detected account ID: $ACCOUNT_ID"
fi

# Auto-detect Region from AWS CLI config if not provided
if [ -z "$REGION" ]; then
    echo "Detecting AWS region from configuration..."
    REGION=$(aws configure get region 2>/dev/null || echo "")
    if [ -z "$REGION" ]; then
        REGION="${AWS_REGION:-ca-central-1}"
    fi
    echo "✓ Using region: $REGION"
fi

# Validate account ID format
if ! [[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "Error: Invalid account ID format. Must be 12 digits. Got: $ACCOUNT_ID"
    exit 1
fi

# Define bucket name
RANDOM_SUFFIX=$(openssl rand -hex 5)
BUCKET_NAME="${BUCKET_PREFIX}-terraform-state-${RANDOM_SUFFIX}-${REGION}"

echo "Creating Terraform backend resources..."
echo "Bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo ""

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "✓ Bucket already exists: $BUCKET_NAME"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✓ Created bucket: $BUCKET_NAME"
fi

# Enable versioning on S3 bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled
echo "✓ Versioning enabled"

# Enable default encryption on S3 bucket
echo "Enabling server-side encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
echo "✓ Default encryption enabled"

# Create backend.hcl file in root
cat > "$BACKEND_HCL" << EOF
bucket  = "$BUCKET_NAME"
key     = "${BUCKET_PREFIX}/terraform.tfstate"
region  = "$REGION"
encrypt = true
EOF

echo ""
echo "✓ Backend setup complete!"
echo "✓ Created: $BACKEND_HCL"
