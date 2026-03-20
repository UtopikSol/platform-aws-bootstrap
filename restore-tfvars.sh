#!/bin/bash
# Restore terraform.tfvars from GitHub secret TFVARS
# Usage: ./restore-tfvars.sh

set -e

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI not installed"
  echo "Install from https://cli.github.com"
  exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Get the repository owner and name
REPO=$(git config --get remote.origin.url | sed 's/.*[:/]\([^/]*\)\/\([^/]*\)\.git$/\1\/\2/')

if [ -z "$REPO" ]; then
  echo "Error: Could not determine repository name"
  exit 1
fi

echo "Restoring terraform.tfvars from GitHub secret..."
echo "Repository: $REPO"

# Retrieve the secret and save to file
if gh secret view TFVARS -R "$REPO" > terraform.tfvars 2>/dev/null; then
  echo "✓ Successfully restored terraform.tfvars"
  echo ""
  echo "Next steps:"
  echo "1. Edit terraform.tfvars as needed"
  echo "2. Run: terraform apply"
  echo "3. The changes will be synced back to GitHub"
else
  echo "Error: Could not retrieve TFVARS secret"
  echo "Make sure:"
  echo "  - You have GitHub CLI authenticated (gh auth login)"
  echo "  - The TFVARS secret exists in the repository"
  exit 1
fi
