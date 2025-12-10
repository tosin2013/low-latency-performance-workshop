#!/bin/bash
# Configure AWS credentials and OpenShift pull secret
#
# This script helps set up:
# 1. AWS CLI credentials file
# 2. OpenShift pull secret
# 3. AgnosticD secrets file

set -e

# ============================================
# Help Function
# ============================================
show_help() {
    cat << EOF
Usage: ./02-configure-aws-credentials.sh [OPTIONS] [subdomain_suffix] [aws_region]

Configure AWS credentials, pull secret, and AgnosticD secrets for the workshop.

Arguments:
  subdomain_suffix    Cluster subdomain (e.g., .sandbox123.opentlc.com)
  aws_region          AWS region (default: us-east-2)

Options:
  -h, --help          Show this help message
  -f, --force         Force reconfiguration (overwrite existing files)
  -s, --show          Show current configuration and exit

Environment Variables:
  SUBDOMAIN_BASE_SUFFIX   Alternative to subdomain_suffix argument
  AWS_REGION              Alternative to aws_region argument

Examples:
  ./02-configure-aws-credentials.sh -h
      Show this help

  ./02-configure-aws-credentials.sh
      Interactive setup (prompts for all values)

  ./02-configure-aws-credentials.sh .sandbox123.opentlc.com
      Set subdomain, use default region (us-east-2)

  ./02-configure-aws-credentials.sh .sandbox123.opentlc.com us-west-2
      Set both subdomain and region

  ./02-configure-aws-credentials.sh -f
      Force reconfiguration of all files

  ./02-configure-aws-credentials.sh --show
      Display current configuration

TIP: Find your subdomain from your hub cluster URL:
     https://api.cluster-abc.sandbox123.opentlc.com:6443
                            ^^^^^^^^^^^^^^^^^^^^^^^^
                            This is your subdomain suffix

EOF
    exit 0
}

# ============================================
# Show Current Configuration
# ============================================
show_config() {
    echo "============================================"
    echo " Current Configuration"
    echo "============================================"
    echo ""
    
    if [ -f ~/secrets-ec2.yml ]; then
        echo "secrets-ec2.yml:"
        echo "  AWS Region:  $(grep aws_region ~/secrets-ec2.yml 2>/dev/null | cut -d':' -f2 | tr -d ' \"' || echo 'not set')"
        echo "  Subdomain:   $(grep subdomain_base_suffix ~/secrets-ec2.yml 2>/dev/null | cut -d':' -f2 | tr -d ' \"' || echo 'not set')"
    else
        echo "secrets-ec2.yml: NOT CONFIGURED"
    fi
    echo ""
    
    if [ -f ~/.aws/credentials ]; then
        echo "AWS Credentials: CONFIGURED"
        echo "  Region: $(grep -E '^region' ~/.aws/credentials 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo 'not set')"
        aws sts get-caller-identity 2>/dev/null && echo "" || echo "  Status: INVALID or expired"
    else
        echo "AWS Credentials: NOT CONFIGURED"
    fi
    echo ""
    
    if [ -f ~/pull-secret.json ]; then
        echo "Pull Secret: CONFIGURED"
    else
        echo "Pull Secret: NOT CONFIGURED"
    fi
    echo ""
    
    echo "To reconfigure, run: ./02-configure-aws-credentials.sh --force"
    exit 0
}

# ============================================
# Parse Arguments
# ============================================
FORCE_RECONFIG=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -f|--force)
            FORCE_RECONFIG=true
            shift
            ;;
        -s|--show)
            show_config
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

SUBDOMAIN_SUFFIX="${1:-${SUBDOMAIN_BASE_SUFFIX:-}}"
AWS_REGION="${2:-${AWS_REGION:-us-east-2}}"

echo "============================================"
echo " AWS Credentials Configuration"
echo "============================================"
echo ""

# Show current config if files exist
if [ -f ~/secrets-ec2.yml ] && [ "${FORCE_RECONFIG}" != "true" ]; then
    echo "Current configuration detected:"
    echo "  Region:    $(grep aws_region ~/secrets-ec2.yml 2>/dev/null | cut -d':' -f2 | tr -d ' \"' || echo 'not set')"
    echo "  Subdomain: $(grep subdomain_base_suffix ~/secrets-ec2.yml 2>/dev/null | cut -d':' -f2 | tr -d ' \"' || echo 'not set')"
    echo ""
    echo "Use --force to reconfigure, or --show for full details"
    echo ""
fi

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
    if [ "${FORCE_RECONFIG}" == "true" ]; then
        echo "Force mode: removing existing AWS credentials"
        rm ~/.aws/credentials
    else
    echo "✓ AWS credentials file already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping AWS credentials setup"
    else
        rm ~/.aws/credentials
        fi
    fi
fi

if [ ! -f ~/.aws/credentials ]; then
    echo "Enter your AWS credentials:"
    read -p "AWS Access Key ID: " AWS_KEY
    read -sp "AWS Secret Access Key: " AWS_SECRET
    echo
    
    # Prompt for region if not set
    if [ -z "${AWS_REGION}" ] || [ "${AWS_REGION}" == "us-east-2" ]; then
        read -p "AWS Region [us-east-2]: " INPUT_REGION
        AWS_REGION="${INPUT_REGION:-us-east-2}"
    fi
    
    mkdir -p ~/.aws
    
    cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_KEY}
aws_secret_access_key = ${AWS_SECRET}
region = ${AWS_REGION}
EOF
    
    chmod 600 ~/.aws/credentials
    echo "✓ AWS credentials configured (region: ${AWS_REGION})"
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
    if [ "${FORCE_RECONFIG}" == "true" ]; then
        echo "Force mode: removing existing pull secret"
        rm ~/pull-secret.json
    else
    echo "✓ Pull secret already exists"
    if jq . ~/pull-secret.json > /dev/null 2>&1; then
        echo "✓ Pull secret is valid JSON"
    else
        echo "⚠ Existing pull secret is invalid JSON"
        rm ~/pull-secret.json
        fi
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
    if [ "${FORCE_RECONFIG}" == "true" ]; then
        echo "Force mode: removing existing secrets-ec2.yml"
        rm ~/secrets-ec2.yml
    else
    echo "✓ secrets-ec2.yml already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing secrets-ec2.yml"
    else
        rm ~/secrets-ec2.yml
        fi
    fi
fi

if [ ! -f ~/secrets-ec2.yml ]; then
    # Read AWS credentials from file
    AWS_KEY=$(grep aws_access_key_id ~/.aws/credentials | cut -d'=' -f2 | tr -d ' ')
    AWS_SECRET=$(grep aws_secret_access_key ~/.aws/credentials | cut -d'=' -f2 | tr -d ' ')
    AWS_REGION_FROM_FILE=$(grep -E "^region" ~/.aws/credentials | cut -d'=' -f2 | tr -d ' ' || echo "us-east-2")
    
    # Use region from credentials file if not set
    AWS_REGION="${AWS_REGION:-${AWS_REGION_FROM_FILE}}"
    
    # Prompt for subdomain if not provided
    if [ -z "${SUBDOMAIN_SUFFIX}" ]; then
        echo ""
        echo "=========================================="
        echo "SUBDOMAIN CONFIGURATION"
        echo "=========================================="
        echo ""
        echo "The subdomain suffix is used for cluster DNS."
        echo ""
        echo "Examples:"
        echo "  RHPDS:      .sandbox123.opentlc.com"
        echo "  Demo:       .dynamic.redhatworkshops.io"
        echo "  Custom:     .mylab.example.com"
        echo ""
        echo "TIP: Check your hub cluster URL to find your subdomain:"
        echo "     https://api.<cluster-name>.<SUBDOMAIN>:6443"
        echo ""
        read -p "Enter subdomain suffix (e.g., .sandbox123.opentlc.com): " SUBDOMAIN_SUFFIX
        
        # Ensure it starts with a dot
        if [[ ! "${SUBDOMAIN_SUFFIX}" =~ ^\. ]]; then
            SUBDOMAIN_SUFFIX=".${SUBDOMAIN_SUFFIX}"
        fi
    fi
    
    cat > ~/secrets-ec2.yml << EOF
---
# Cloud Provider
cloud_provider: ec2

# AWS Credentials
aws_access_key_id: ${AWS_KEY}
aws_secret_access_key: ${AWS_SECRET}

# AWS Region
aws_region: ${AWS_REGION}

# Subdomain for cluster DNS
subdomain_base_suffix: "${SUBDOMAIN_SUFFIX}"

# OpenShift Pull Secret (REQUIRED)
ocp4_pull_secret: '{{ lookup("file", "/runner/pull-secret.json") }}'

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
    echo "  Region: ${AWS_REGION}"
    echo "  Subdomain: ${SUBDOMAIN_SUFFIX}"
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
echo "Configuration Summary:"
echo "  AWS Region:  $(grep aws_region ~/secrets-ec2.yml | cut -d':' -f2 | tr -d ' \"')"
echo "  Subdomain:   $(grep subdomain_base_suffix ~/secrets-ec2.yml | cut -d':' -f2 | tr -d ' \"')"

echo ""
echo "============================================"
echo " ✓ Configuration Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Test single SNO: ./03-test-single-sno.sh student1"
echo "  2. Or provision all: ./04-provision-student-clusters.sh 30"
echo "  3. Multi-user workshop: ./08-provision-complete-workshop.sh 5"
echo ""


