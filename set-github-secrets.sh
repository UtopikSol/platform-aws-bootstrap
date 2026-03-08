#!/bin/bash
# set-github-secrets.sh - Automatically set AWS_ROLE_TO_ASSUME secrets in all repositories

set -e

ORG=${1:-}
ACCOUNT_ID=${2:-}

if [ -z "$ORG" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "Usage: ./set-github-secrets.sh <github-org> <aws-account-id>"
  echo ""
  echo "Example: ./set-github-secrets.sh your-org 123456789012"
  echo ""
  echo "This script sets AWS_ROLE_TO_ASSUME secret in all repositories"
  echo "using the GitHub CLI (gh). Make sure you're authenticated:"
  echo "  gh auth login"
  exit 1
fi

# Read repositories from repositories.json
REPOS=$(jq -r '.repositories[].name' repositories.json)

echo "Setting AWS_ROLE_TO_ASSUME secrets for ${#REPOS[@]} repositories..."
echo "Organization: $ORG"
echo "Account ID: $ACCOUNT_ID"
echo ""

for REPO in $REPOS; do
  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/github-${ORG}-${REPO}"
  
  echo "Setting secret in ${ORG}/${REPO}..."
  echo "$ROLE_ARN" | gh secret set AWS_ROLE_TO_ASSUME --repo "${ORG}/${REPO}"
  
  echo "  ✓ Secret set: $ROLE_ARN"
done

echo ""
echo "✓ All secrets set successfully!"
echo ""
echo "Next steps:"
echo "1. Verify secrets in GitHub: gh secret list --repo <org>/<repo>"
echo "2. Update workflows to use: \${{ secrets.AWS_ROLE_TO_ASSUME }}"
