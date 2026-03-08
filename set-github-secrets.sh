#!/bin/bash
# set-github-secrets.sh - Set AWS_ACCOUNT_ID as organization secret

set -e

ACCOUNT_ID=${1:-}

if [ -z "$ACCOUNT_ID" ]; then
  echo "Usage: ./set-github-secrets.sh <aws-account-id>"
  echo ""
  echo "Example: ./set-github-secrets.sh 123456789012"
  echo ""
  echo "This script sets AWS_ACCOUNT_ID as an ORGANIZATION SECRET."
  echo "The organization is read from repositories.json"
  echo ""
  echo "Benefits:"
  echo "  • Single source of truth"
  echo "  • Available to all current and future repos"
  echo "  • No per-repository setup needed"
  echo "  • Survives user removals"
  echo ""
  echo "To authenticate with gh CLI:"
  echo "  gh auth login"
  echo ""
  exit 1
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) is not installed."
  echo "   Install it from: https://cli.github.com"
  exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
  echo "❌ Not authenticated with GitHub CLI."
  echo "   Run: gh auth login"
  exit 1
fi

# Verify authentication
echo "Verifying GitHub authentication..."
if ! gh api user -q .login > /dev/null 2>&1; then
  echo "❌ GitHub authentication failed."
  exit 1
fi

USERNAME=$(gh api user -q .login)
echo "✓ Authenticated as: $USERNAME"
echo ""

# Validate AWS Account ID format
if ! [[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "❌ Invalid AWS Account ID format (must be 12 digits)"
  exit 1
fi

# Read organization from repositories.json
if [ ! -f "repositories.json" ]; then
  echo "❌ repositories.json not found. Are you in the project root?"
  exit 1
fi

ORG=$(jq -r '.githubOwner' repositories.json)
if [ -z "$ORG" ] || [ "$ORG" = "null" ]; then
  echo "❌ githubOwner not found in repositories.json"
  exit 1
fi

echo "Setting organization secret: AWS_ACCOUNT_ID = $ACCOUNT_ID"
echo "Organization: $ORG"
echo ""

# Try to set organization secret
if echo "$ACCOUNT_ID" | gh secret set AWS_ACCOUNT_ID --org "$ORG" 2>/dev/null; then
  echo "✓ Organization secret set successfully!"
  echo ""
  echo "=================================="
  echo "Setup Complete!"
  echo "=================================="
  echo ""
  echo "The AWS_ACCOUNT_ID secret is now available to:"
  echo "  • All repositories in: $ORG"
  echo "  • Current and future repositories"
  echo "  • All workflows in those repositories"
  echo ""
  echo "Accessed in workflows as: \${{ secrets.AWS_ACCOUNT_ID }}"
  echo ""
  echo "To verify:"
  echo "  gh secret list --org $ORG"
  echo ""
  echo "To update in the future:"
  echo "  ./set-github-secrets.sh <new-account-id>"
else
  echo "❌ Failed to set organization secret."
  echo ""
  echo "This requires organization admin permissions."
  echo "Make sure your GitHub account is an organization owner."
  echo ""
  echo "Alternative: Set manually via GitHub UI"
  echo "  https://github.com/organizations/$ORG/settings/secrets/actions"
  exit 1
fi
