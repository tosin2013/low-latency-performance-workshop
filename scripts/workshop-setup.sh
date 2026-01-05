#!/bin/bash
# -------------------------------------------------------------------
# Workshop Setup Script
#
# Full automated setup for Low-Latency Performance Workshop deployment
# using AgnosticD V2
#
# This script:
# 1. Checks prerequisites (OS, podman, python3.12+)
# 2. Clones required repositories
# 3. Creates directory structure
# 4. Sets up symlinks
# 5. Generates secrets templates
# 6. Runs agd setup
# 7. Optionally prompts for configuration
# -------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default paths
DEVELOPMENT_DIR="${HOME}/Development"
AGNOSTICD_DIR="${DEVELOPMENT_DIR}/agnosticd-v2"
WORKSHOP_DIR="${DEVELOPMENT_DIR}/low-latency-performance-workshop"
VARS_DIR="${DEVELOPMENT_DIR}/agnosticd-v2-vars"
SECRETS_DIR="${DEVELOPMENT_DIR}/agnosticd-v2-secrets"
OUTPUT_DIR="${DEVELOPMENT_DIR}/agnosticd-v2-output"

# Interactive mode (can be disabled with --non-interactive)
INTERACTIVE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --non-interactive)
      INTERACTIVE=false
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--non-interactive]"
      exit 1
      ;;
  esac
done

# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------

print_section() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "  ${YELLOW}→${NC} $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# -------------------------------------------------------------------
# 1. Prerequisites Check
# -------------------------------------------------------------------

print_section "Checking Prerequisites"

# Check OS
OS_TYPE="unknown"
if [[ "$(uname)" == "Darwin" ]]; then
  OS_TYPE="macos"
  print_success "Detected macOS"
elif [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "$ID" == "rhel" ]]; then
    OS_TYPE="rhel"
    print_success "Detected RHEL ${VERSION_ID}"
  elif [[ "$ID" == "fedora" ]]; then
    OS_TYPE="fedora"
    print_success "Detected Fedora ${VERSION_ID}"
  fi
fi

if [[ "$OS_TYPE" == "unknown" ]]; then
  print_error "Unsupported operating system"
  echo "Supported: RHEL 9.5+, RHEL 10.0+, Fedora 41+, macOS Sequoia+"
  exit 1
fi

# Check podman
if ! command_exists podman; then
  print_error "podman is not installed"
  if [[ "$OS_TYPE" == "macos" ]]; then
    print_info "Install with: brew install podman"
  else
    print_info "Install with: sudo dnf install podman"
  fi
  exit 1
fi
print_success "podman is installed"

# Check python3
if ! command_exists python3; then
  print_error "python3 is not installed"
  exit 1
fi

# Check python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

if [[ "$PYTHON_MAJOR" -lt 3 ]] || [[ "$PYTHON_MAJOR" -eq 3 && "$PYTHON_MINOR" -lt 12 ]]; then
  print_error "Python 3.12+ is required (found $PYTHON_VERSION)"
  exit 1
fi
print_success "python3 $PYTHON_VERSION is installed"

# Check git
if ! command_exists git; then
  print_error "git is not installed"
  exit 1
fi
print_success "git is installed"

# -------------------------------------------------------------------
# 2. Clone Repositories
# -------------------------------------------------------------------

print_section "Setting Up Repositories"

# Create Development directory
if [[ ! -d "$DEVELOPMENT_DIR" ]]; then
  print_info "Creating $DEVELOPMENT_DIR"
  mkdir -p "$DEVELOPMENT_DIR"
fi

# Clone agnosticd-v2 if not present
if [[ ! -d "$AGNOSTICD_DIR" ]]; then
  print_info "Cloning agnosticd-v2 repository..."
  cd "$DEVELOPMENT_DIR"
  git clone https://github.com/agnosticd/agnosticd-v2.git || {
    print_error "Failed to clone agnosticd-v2"
    exit 1
  }
  print_success "Cloned agnosticd-v2"
else
  print_success "agnosticd-v2 already exists"
fi

# Note: Workshop repo is assumed to be already cloned (we're running from it)
if [[ ! -d "$WORKSHOP_DIR" ]]; then
  print_warning "Workshop directory not found at $WORKSHOP_DIR"
  print_info "If you want to clone it:"
  print_info "  git clone https://github.com/tosin2013/low-latency-performance-workshop.git $WORKSHOP_DIR"
fi

# -------------------------------------------------------------------
# 3. Create Directory Structure
# -------------------------------------------------------------------

print_section "Creating Directory Structure"

for dir in "$SECRETS_DIR" "$OUTPUT_DIR"; do
  if [[ ! -d "$dir" ]]; then
    print_info "Creating $dir"
    mkdir -p "$dir"
    print_success "Created $dir"
  else
    print_success "$dir already exists"
  fi
done

# -------------------------------------------------------------------
# 4. Symlink Workshop Vars
# -------------------------------------------------------------------

print_section "Setting Up Configuration Symlink"

WORKSHOP_VARS_DIR="${WORKSHOP_DIR}/agnosticd-v2-vars"

if [[ ! -d "$WORKSHOP_VARS_DIR" ]]; then
  print_error "Workshop vars directory not found: $WORKSHOP_VARS_DIR"
  print_info "Make sure you're running this from the workshop repository"
  exit 1
fi

# Remove existing symlink or directory if it exists
if [[ -L "$VARS_DIR" ]]; then
  print_info "Removing existing symlink: $VARS_DIR"
  rm "$VARS_DIR"
elif [[ -d "$VARS_DIR" ]]; then
  print_warning "$VARS_DIR already exists as a directory"
  print_info "Creating backup symlink: ${VARS_DIR}.backup"
  mv "$VARS_DIR" "${VARS_DIR}.backup"
fi

# Create symlink
print_info "Creating symlink: $VARS_DIR -> $WORKSHOP_VARS_DIR"
ln -sf "$WORKSHOP_VARS_DIR" "$VARS_DIR"
print_success "Symlink created"

# -------------------------------------------------------------------
# 5. Generate Secrets Templates
# -------------------------------------------------------------------

print_section "Setting Up Secrets Templates"

# Copy secrets templates if they don't exist
if [[ ! -f "${SECRETS_DIR}/secrets.yml" ]]; then
  print_info "Creating secrets.yml template"
  cat > "${SECRETS_DIR}/secrets.yml" << 'EOF'
---
# -------------------------------------------------------------------
# Satellite Repos
# -------------------------------------------------------------------
host_satellite_repositories_hostname: <Your Satellite URL here>
host_satellite_repositories_ha: true
host_satellite_repositories_org: <Your Org Here>
host_satellite_repositories_activationkey: <Your Activation Key here>

# -------------------------------------------------------------------
# RHN Repos
# -------------------------------------------------------------------
# host_rhn_repositories_username: <Your RHN Username>
# host_rhn_repositories_password: <Your RHN Password>

# -------------------------------------------------------------------
# OpenShift Secrets
# -------------------------------------------------------------------
ocp4_pull_secret: '<Add Your Pull Secret here>'
EOF
  print_success "Created secrets.yml template"
else
  print_success "secrets.yml already exists"
fi

if [[ ! -f "${SECRETS_DIR}/secrets-sandboxXXX.yml" ]]; then
  print_info "Creating secrets-sandboxXXX.yml template"
  cat > "${SECRETS_DIR}/secrets-sandboxXXX.yml" << 'EOF'
---
# Request an AWS Open Environment on https://demo.redhat.com and fill in the values from that
# environment below
aws_access_key_id: <Your AWS Access Key ID here>
aws_secret_access_key: <Your AWS Secret Access Key here>

# Replace XXX with your sandbox number and rename this
# file to secrets-sandboxXXX.yml where XXX is the number of
# your assigned sandbox
base_domain: sandboxXXX.opentlc.com

# Don't use capacity reservations when deploying locally
agnosticd_aws_capacity_reservation_enable: false
EOF
  print_success "Created secrets-sandboxXXX.yml template"
else
  print_success "secrets-sandboxXXX.yml already exists"
fi

# -------------------------------------------------------------------
# 6. Run agd setup
# -------------------------------------------------------------------

print_section "Running AgnosticD V2 Setup"

if [[ ! -f "${AGNOSTICD_DIR}/bin/agd" ]]; then
  print_error "agd script not found at ${AGNOSTICD_DIR}/bin/agd"
  exit 1
fi

cd "$AGNOSTICD_DIR"
print_info "Running: ./bin/agd setup"
./bin/agd setup || {
  print_error "agd setup failed"
  exit 1
}
print_success "AgnosticD V2 setup completed"

# -------------------------------------------------------------------
# 7. Interactive Configuration (Optional)
# -------------------------------------------------------------------

if [[ "$INTERACTIVE" == "true" ]]; then
  print_section "Interactive Configuration"
  
  echo "You can now configure your deployment files:"
  echo ""
  echo "1. Edit ${SECRETS_DIR}/secrets.yml:"
  echo "   - Add OpenShift pull secret"
  echo "   - Configure Satellite or RHN repositories"
  echo ""
  echo "2. Create ${SECRETS_DIR}/secrets-sandboxXXX.yml:"
  echo "   - Add AWS credentials from demo.redhat.com"
  echo "   - Replace XXX with your sandbox number"
  echo ""
  echo "3. Edit ${WORKSHOP_VARS_DIR}/low-latency-sno-aws.yml:"
  echo "   - Update cloud_tags.owner with your email"
  echo "   - Add host_ssh_authorized_keys with your GitHub username"
  echo ""
  
  read -p "Would you like to configure these files now? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Prompt for sandbox number
    read -p "Enter your AWS sandbox number (e.g., 1234): " SANDBOX_NUM
    if [[ -n "$SANDBOX_NUM" ]]; then
      SANDBOX_FILE="${SECRETS_DIR}/secrets-sandbox${SANDBOX_NUM}.yml"
      if [[ ! -f "$SANDBOX_FILE" ]]; then
        cp "${SECRETS_DIR}/secrets-sandboxXXX.yml" "$SANDBOX_FILE"
        sed -i "s/sandboxXXX/sandbox${SANDBOX_NUM}/g" "$SANDBOX_FILE"
        print_success "Created $SANDBOX_FILE"
        print_info "Please edit this file and add your AWS credentials"
      fi
    fi
    
    # Prompt for email
    read -p "Enter your email address for cloud tags: " EMAIL
    if [[ -n "$EMAIL" ]]; then
      CONFIG_FILE="${WORKSHOP_VARS_DIR}/low-latency-sno-aws.yml"
      if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/user@example.com/${EMAIL}/g" "$CONFIG_FILE"
        print_success "Updated email in config file"
      fi
    fi
    
    # Prompt for GitHub username
    read -p "Enter your GitHub username for SSH keys: " GITHUB_USER
    if [[ -n "$GITHUB_USER" ]]; then
      CONFIG_FILE="${WORKSHOP_VARS_DIR}/low-latency-sno-aws.yml"
      if [[ -f "$CONFIG_FILE" ]]; then
        # Add SSH keys section if not present
        if ! grep -q "host_ssh_authorized_keys:" "$CONFIG_FILE"; then
          # Find the line with "# SSH Keys" and add after it
          sed -i "/# SSH Keys/a host_ssh_authorized_keys:\n  - key: https://github.com/${GITHUB_USER}.keys" "$CONFIG_FILE"
        else
          # Update existing entry
          sed -i "s|https://github.com/username.keys|https://github.com/${GITHUB_USER}.keys|g" "$CONFIG_FILE"
        fi
        print_success "Updated GitHub username in config file"
      fi
    fi
  fi
fi

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------

print_section "Setup Complete!"

echo "Next steps:"
echo ""
echo "1. Configure secrets:"
echo "   - Edit ${SECRETS_DIR}/secrets.yml (add pull secret)"
echo "   - Edit ${SECRETS_DIR}/secrets-sandboxXXX.yml (add AWS credentials)"
echo ""
echo "2. Configure deployment:"
echo "   - Edit ${WORKSHOP_VARS_DIR}/low-latency-sno-aws.yml"
echo ""
echo "3. Deploy a cluster:"
echo "   cd ${AGNOSTICD_DIR}"
echo "   ./bin/agd provision -g student1 -c low-latency-sno-aws -a sandboxXXX"
echo ""
echo "Or use the helper scripts:"
echo "   ${WORKSHOP_DIR}/scripts/deploy-sno.sh student1 sandboxXXX"
echo ""

