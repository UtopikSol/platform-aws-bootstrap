#!/bin/bash

# Merged script to restore both backend and terraform variables
# - Attempts to create/restore backend S3 bucket and backend.hcl config
# - Attempts to restore terraform.tfvars from GitHub secret
# - Creates default files if restoration fails
# 
# Usage: ./init.sh [account-id] [region] [backend-hcl] [bucket-prefix]
# Example: ./init.sh (auto-detect from SSO)
# Example: ./init.sh 198252713378 ca-central-1

set +e  # Don't exit on errors - we'll handle them selectively

# ============================================================================
# COLORS FOR OUTPUT
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# PARSE ARGUMENTS (for backend configuration)
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

ACCOUNT_ID="${1:-}"
REGION="${2:-}"
BACKEND_HCL="${3:-${PROJECT_ROOT}/backend.hcl}"
BUCKET_PREFIX="${4:-bootstrap}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Configuration Restore${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# SECTION 1: RESTORE/CREATE BACKEND CONFIGURATION
# ============================================================================
echo -e "${YELLOW}[1/2] Backend Configuration${NC}"
echo ""

# Auto-detect Account ID from AWS SSO session if not provided
if [ -z "$ACCOUNT_ID" ]; then
    echo "Detecting AWS account ID from SSO session..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ -z "$ACCOUNT_ID" ]; then
        echo -e "${RED}✗ Could not detect account ID${NC}"
        echo "  Please ensure AWS credentials are configured or provide account ID:"
        echo "  Usage: ./init.sh <account-id> [region]"
        exit 1
    fi
    echo -e "${GREEN}✓ Detected account ID: $ACCOUNT_ID${NC}"
fi

# Auto-detect Region from AWS CLI config if not provided
if [ -z "$REGION" ]; then
    echo "Detecting AWS region from configuration..."
    REGION=$(aws configure get region 2>/dev/null || echo "")
    if [ -z "$REGION" ]; then
        REGION="${AWS_REGION:-ca-central-1}"
    fi
    echo -e "${GREEN}✓ Using region: $REGION${NC}"
fi

# Validate account ID format
if ! [[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo -e "${RED}✗ Invalid account ID format. Must be 12 digits. Got: $ACCOUNT_ID${NC}"
    exit 1
fi

# Define bucket name
RANDOM_SUFFIX=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text 2>/dev/null | tr -d '-')
if [ -z "$RANDOM_SUFFIX" ]; then
    RANDOM_SUFFIX=$(echo -n "$ACCOUNT_ID" | tail -c 8)
fi
BUCKET_NAME="${BUCKET_PREFIX}-terraform-state-${RANDOM_SUFFIX}-${REGION}"

echo "Backend bucket: $BUCKET_NAME"
echo ""

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓ Bucket already exists: $BUCKET_NAME${NC}"
else
    echo "Bucket does not exist. Attempting to create..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" 2>/dev/null && echo -e "${GREEN}✓ Created bucket: $BUCKET_NAME${NC}" || echo -e "${RED}✗ Failed to create bucket${NC}"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null && echo -e "${GREEN}✓ Created bucket: $BUCKET_NAME${NC}" || echo -e "${RED}✗ Failed to create bucket${NC}"
    fi
fi

# Enable versioning on S3 bucket (non-critical)
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled 2>/dev/null && echo -e "${GREEN}✓ Versioning enabled${NC}" || echo -e "${RED}✗ Failed to enable versioning${NC}"

# Enable default encryption on S3 bucket (non-critical)
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' 2>/dev/null && echo -e "${GREEN}✓ Default encryption enabled${NC}" || echo -e "${RED}✗ Failed to enable encryption${NC}"

# Create backend.hcl file
cat > "$BACKEND_HCL" << EOF
bucket  = "$BUCKET_NAME"
key     = "${BUCKET_PREFIX}/terraform.tfstate"
region  = "$REGION"
encrypt = true
EOF

echo -e "${GREEN}✓ Created: $BACKEND_HCL${NC}"
echo ""

# ============================================================================
# SECTION 2: RESTORE/CREATE TERRAFORM VARIABLES
# ============================================================================
echo -e "${YELLOW}[2/2] Terraform Variables (terraform.tfvars)${NC}"
echo ""

TFVARS_FILE="${PROJECT_ROOT}/terraform.tfvars"
RESTORATION_SUCCESSFUL=false

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Will create default terraform.tfvars from template."
else
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Not in a git repository. Will create default terraform.tfvars from template."
    else
        # Try to get repository name
        REPO=$(git config --get remote.origin.url | sed 's/.*[:/]\([^/]*\)\/\([^/]*\)\.git$/\1\/\2/')
        if [ -z "$REPO" ]; then
            echo "Could not determine repository name. Will create default terraform.tfvars from template."
        else
            echo "Attempting to restore terraform.tfvars from GitHub secret..."
            echo "Repository: $REPO"
            
            if gh secret view TFVARS -R "$REPO" > "$TFVARS_FILE" 2>/dev/null; then
                echo -e "${GREEN}✓ Successfully restored terraform.tfvars${NC}"
                RESTORATION_SUCCESSFUL=true
            else
                echo -e "${RED}✗ Could not retrieve TFVARS secret${NC}"
                echo "  Make sure:"
                echo "    - GitHub CLI is authenticated (gh auth login)"
                echo "    - TFVARS secret exists in the repository"
            fi
        fi
    fi
fi

# Create default terraform.tfvars if restoration failed
if [ "$RESTORATION_SUCCESSFUL" = false ]; then
    echo "Creating default terraform.tfvars from template..."
    
    if [ -f "${PROJECT_ROOT}/terraform.tfvars.example" ]; then
        cp "${PROJECT_ROOT}/terraform.tfvars.example" "$TFVARS_FILE"
        echo -e "${GREEN}✓ Created $TFVARS_FILE from template${NC}"
    else
        # Create minimal terraform.tfvars if no template exists
        cat > "$TFVARS_FILE" << 'EOF'
# Terraform variables - Edit as needed and sync to GitHub as TFVARS secret
# See terraform.tfvars.example for all available options

# Example variables (uncomment and fill in):
# github_token = "ghp_..."
# github_org   = "your-org"
EOF
        echo -e "${GREEN}✓ Created default $TFVARS_FILE${NC}"
    fi
    
    echo -e "${YELLOW}⚠ Please edit terraform.tfvars with your configuration${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Restoration complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Review and edit terraform.tfvars if needed"
echo "  2. Run: terraform init"
echo "  3. Run: terraform apply"
echo ""
