#!/bin/bash
# Configure AWS credentials and OpenShift pull secret
#
# This script helps set up:
# 1. AWS CLI credentials file
# 2. OpenShift pull secret
# 3. AgnosticD secrets file

set -e

echo "============================================"
echo " AWS Credentials Configuration"
echo "============================================"
echo ""

# ============================================
# Check for AWS CLI
# ============================================
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    pip3 install --user awscli
    export PATH=$PATH:~/.local/bin
fi

# ============================================
# Configure AWS Credentials
# ============================================
echo "[1/3] AWS Credentials Setup"
echo ""

if [ -f ~/.aws/credentials ]; then
    echo "✓ AWS credentials file already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping AWS credentials setup"
    else
        rm ~/.aws/credentials
    fi
fi

if [ ! -f ~/.aws/credentials ]; then
    echo "Enter your AWS credentials:"
    read -p "AWS Access Key ID: " AWS_KEY
    read -sp "AWS Secret Access Key: " AWS_SECRET
    echo
    
    mkdir -p ~/.aws
    
    cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_KEY}
aws_secret_access_key = ${AWS_SECRET}
region = us-east-1
EOF
    
    chmod 600 ~/.aws/credentials
    echo "✓ AWS credentials configured"
fi

# Test AWS credentials
echo ""
echo "Testing AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✓ AWS credentials valid"
    aws sts get-caller-identity
else
    echo "✗ AWS credentials test failed"
    echo "Please check your access key and secret"
    exit 1
fi

# ============================================
# OpenShift Pull Secret
# ============================================
echo ""
echo "[2/3] OpenShift Pull Secret Setup"
echo ""

if [ -f ~/pull-secret.json ]; then
    echo "✓ Pull secret already exists"
    if jq . ~/pull-secret.json > /dev/null 2>&1; then
        echo "✓ Pull secret is valid JSON"
    else
        echo "⚠ Existing pull secret is invalid JSON"
        rm ~/pull-secret.json
    fi
fi

if [ ! -f ~/pull-secret.json ]; then
    echo ""
    echo "=========================================="
    echo "ACTION REQUIRED:"
    echo "1. Visit: https://console.redhat.com/openshift/install/pull-secret"
    echo "2. Login with your Red Hat account"
    echo "3. Copy the pull secret"
    echo "=========================================="
    echo ""
    echo "Paste your pull secret (it should start with '{' and end with '}'):"
    echo "Then press Ctrl+D when done"
    echo ""
    
    cat > ~/pull-secret.json
    
    # Validate JSON
    if jq . ~/pull-secret.json > /dev/null 2>&1; then
        chmod 600 ~/pull-secret.json
        echo ""
        echo "✓ Pull secret saved and validated"
    else
        echo ""
        echo "✗ Invalid JSON format. Please try again."
        rm ~/pull-secret.json
        exit 1
    fi
fi

# ============================================
# AgnosticD Secrets File
# ============================================
echo ""
echo "[3/3] AgnosticD Secrets File Setup"
echo ""

if [ -f ~/secrets-ec2.yml ]; then
    echo "✓ secrets-ec2.yml already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing secrets-ec2.yml"
    else
        rm ~/secrets-ec2.yml
    fi
fi

if [ ! -f ~/secrets-ec2.yml ]; then
    # Read AWS credentials from file
    AWS_KEY=$(grep aws_access_key_id ~/.aws/credentials | cut -d'=' -f2 | tr -d ' ')
    AWS_SECRET=$(grep aws_secret_access_key ~/.aws/credentials | cut -d'=' -f2 | tr -d ' ')
    
    cat > ~/secrets-ec2.yml << EOF
---
# Cloud Provider
cloud_provider: ec2

# AWS Credentials
aws_access_key_id: ${AWS_KEY}
aws_secret_access_key: ${AWS_SECRET}

# AWS Region
aws_region: us-east-1

# Subdomain (RHPDS standard)
subdomain_base_suffix: ".dynamic.redhatworkshops.io"

# OpenShift Pull Secret (REQUIRED)
ocp4_pull_secret: '{{ lookup("file", "~/pull-secret.json") }}'

# ========================================
# NOTE: NO repo_method Configuration!
# ========================================
# SNO uses CoreOS (not RHEL), so we do NOT need:
#   - repo_method: satellite
#   - set_repositories_satellite_*
#   - rhel_subscription_user/pass
# ========================================
EOF
    
    chmod 600 ~/secrets-ec2.yml
    echo "✓ secrets-ec2.yml created"
fi

# ============================================
# Verification
# ============================================
echo ""
echo "============================================"
echo " Verification"
echo "============================================"
echo ""

echo "Files created:"
ls -lh ~/.aws/credentials ~/pull-secret.json ~/secrets-ec2.yml

echo ""
echo "AWS Account:"
aws sts get-caller-identity | jq -r '.Account'

echo ""
echo "============================================"
echo " ✓ Configuration Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Test single SNO: ./03-test-single-sno.sh student1"
echo "  2. Or provision all: ./04-provision-student-clusters.sh 30"
echo ""


