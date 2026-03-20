#!/usr/bin/env bash
# Setup script for git hooks
# Run this after cloning the repository

set -euo pipefail

echo "Setting up git hooks..."

# Configure git to include the tracked .gitconfig
git config --local include.path ../.gitconfig

echo "✓ Git hooks configured successfully!"
echo "  Pre-commit hooks will now run automatically on every commit."
