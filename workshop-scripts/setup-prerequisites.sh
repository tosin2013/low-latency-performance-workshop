#!/bin/bash
# Setup all prerequisites for the Low-Latency Performance Workshop
#
# Usage:
#   ./setup-prerequisites.sh
#
# This script sets up:
#   1. Ansible Navigator (for AgnosticD deployments)
#   2. AWS credentials (for SNO cluster provisioning)
#   3. RHACM on hub cluster (optional, if not already installed)
#
# Run this ONCE before provisioning the workshop.

set -e

WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
SCRIPT_DIR="${WORKSHOP_DIR}/workshop-scripts"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     WORKSHOP PREREQUISITES SETUP                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# Step 1: Ansible Navigator
# ============================================
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [1/3] Setting up Ansible Navigator                        │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

if command -v ansible-navigator &> /dev/null; then
    echo "✓ Ansible Navigator already installed"
    ansible-navigator --version | head -1
else
    echo "Installing Ansible Navigator..."
    if [ -f "${SCRIPT_DIR}/helpers/01-setup-ansible-navigator.sh" ]; then
        ${SCRIPT_DIR}/helpers/01-setup-ansible-navigator.sh
    else
        echo "Installing via pip..."
        pip3 install --user ansible-navigator
    fi
fi
echo ""

# ============================================
# Step 2: AWS Credentials
# ============================================
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [2/3] Configuring AWS Credentials                         │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

if [ -f ~/secrets-ec2.yml ]; then
    echo "✓ AWS credentials file exists: ~/secrets-ec2.yml"
    echo ""
    read -p "Reconfigure AWS credentials? (yes/no): " RECONFIG
    if [ "${RECONFIG}" == "yes" ]; then
        ${SCRIPT_DIR}/helpers/02-configure-aws-credentials.sh
    fi
else
    echo "AWS credentials not configured."
    ${SCRIPT_DIR}/helpers/02-configure-aws-credentials.sh
fi
echo ""

# ============================================
# Step 3: RHACM Check
# ============================================
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [3/3] Checking RHACM Installation                         │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

if oc whoami &> /dev/null; then
    echo "✓ Logged into cluster: $(oc whoami --show-server)"
    
    if oc get multiclusterhub -n open-cluster-management &> /dev/null; then
        echo "✓ RHACM is installed"
        MCH_STATUS=$(oc get multiclusterhub -n open-cluster-management -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
        echo "  Status: ${MCH_STATUS}"
    else
        echo "⚠ RHACM not found on this cluster"
        echo ""
        read -p "Install RHACM now? (yes/no): " INSTALL_RHACM
        if [ "${INSTALL_RHACM}" == "yes" ]; then
            if [ -f "${SCRIPT_DIR}/helpers/00-install-rhacm.sh" ]; then
                ${SCRIPT_DIR}/helpers/00-install-rhacm.sh
            else
                echo "RHACM install script not found"
            fi
        fi
    fi
else
    echo "⚠ Not logged into any OpenShift cluster"
    echo "Run: oc login <hub-api-url>"
fi
echo ""

# ============================================
# Summary
# ============================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     PREREQUISITES SETUP COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Status:"

# Check Ansible Navigator
if command -v ansible-navigator &> /dev/null; then
    echo "  ✓ Ansible Navigator: Installed"
else
    echo "  ✗ Ansible Navigator: Not found"
fi

# Check AWS credentials
if [ -f ~/secrets-ec2.yml ]; then
    echo "  ✓ AWS Credentials: Configured"
else
    echo "  ✗ AWS Credentials: Not configured"
fi

# Check AgnosticD
if [ -d ~/agnosticd ]; then
    echo "  ✓ AgnosticD: Available"
else
    echo "  ✗ AgnosticD: Not found (clone from github.com/redhat-cop/agnosticd)"
fi

# Check OC login
if oc whoami &> /dev/null; then
    echo "  ✓ OpenShift Login: $(oc whoami)@$(oc whoami --show-server)"
else
    echo "  ✗ OpenShift Login: Not logged in"
fi

echo ""
echo "Next step:"
echo "  ./provision-workshop.sh <num_students>"
echo ""
echo "Example:"
echo "  ./provision-workshop.sh 10    # Deploy workshop for 10 students"
echo ""

