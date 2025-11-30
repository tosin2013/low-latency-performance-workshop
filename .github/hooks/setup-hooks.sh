#!/bin/bash
# Setup script to install git hooks for this repository
#
# Usage: ./setup-hooks.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/.git/hooks"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Setting up Git Hooks                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if .git directory exists
if [ ! -d "${REPO_ROOT}/.git" ]; then
    echo "❌ Error: Not in a git repository"
    echo "   Run this script from within the repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "${HOOKS_DIR}"

# Install pre-commit hook
echo "Installing pre-commit hook..."
cp "${SCRIPT_DIR}/pre-commit" "${HOOKS_DIR}/pre-commit"
chmod +x "${HOOKS_DIR}/pre-commit"
echo "✅ Installed: .git/hooks/pre-commit"

# Check if gitleaks is installed
echo ""
echo "Checking for gitleaks..."
if command -v gitleaks &> /dev/null; then
    echo "✅ gitleaks is installed: $(gitleaks version | head -1)"
else
    echo "⚠️  gitleaks not found"
    echo ""
    echo "The pre-commit hook will attempt to install gitleaks automatically,"
    echo "but you can install it manually for better performance:"
    echo ""
    echo "  macOS:   brew install gitleaks"
    echo "  Linux:   See https://github.com/gitleaks/gitleaks#installing"
    echo ""
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  ✅ Git Hooks Setup Complete!                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Installed hooks:"
echo "  • pre-commit: Scans for secrets before each commit"
echo ""
echo "The pre-commit hook will:"
echo "  1. Run gitleaks on staged files before each commit"
echo "  2. Block commits that contain secrets"
echo "  3. Help prevent accidental credential leaks"
echo ""
echo "To test the hook, try:"
echo "  echo 'aws_key=AKIAIOSFODNN7EXAMPLE' > test.txt"
echo "  git add test.txt"
echo "  git commit -m 'test'"
echo ""
echo "For more information, see:"
echo "  docs/deployment/SECURITY_GUIDELINES.md"
echo ""

