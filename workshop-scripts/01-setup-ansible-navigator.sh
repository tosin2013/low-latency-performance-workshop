#!/bin/bash
# Setup ansible-navigator with AgnosticD execution environment
#
# This script:
# 1. Installs ansible-navigator via pip3
# 2. Creates ~/.ansible-navigator.yaml configuration
# 3. Pulls AgnosticD execution environment image
# 4. Verifies installation

set -e

echo "============================================"
echo " ansible-navigator Setup"
echo "============================================"
echo ""

# ============================================
# Step 1: Check/Install ansible-navigator
# ============================================
echo "[1/4] Checking ansible-navigator installation..."

if command -v ansible-navigator &> /dev/null; then
    echo "✓ ansible-navigator already installed: $(ansible-navigator --version | head -1)"
else
    echo "Installing ansible-navigator..."
    pip3 install --user 'ansible-navigator[ansible-core]'
    
    # Add to PATH
    export PATH=$PATH:~/.local/bin
    
    # Add to bashrc for persistence
    if ! grep -q 'export PATH=$PATH:~/.local/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    fi
    
    echo "✓ ansible-navigator installed"
fi

# ============================================
# Step 2: Check podman
# ============================================
echo ""
echo "[2/4] Checking podman installation..."

if command -v podman &> /dev/null; then
    echo "✓ podman available: $(podman --version)"
else
    echo "⚠ podman not found. Installing..."
    sudo dnf install -y podman
fi

# ============================================
# Step 3: Create Configuration
# ============================================
echo ""
echo "[3/4] Creating ansible-navigator configuration..."

cat > ~/.ansible-navigator.yaml << 'EOF'
---
ansible-navigator:
  execution-environment:
    # Enable containerized execution
    enabled: true
    
    # Use AgnosticD's multi-cloud execution environment
    image: quay.io/agnosticd/ee-multicloud:latest
    
    # Container engine
    container-engine: podman
    
    # Pull policy
    pull:
      policy: missing  # Only pull if not present locally
    
    # Volume mounts - critical for accessing local files
    volume-mounts:
      - src: "~/"
        dest: "/runner"
        options: "Z"  # SELinux relabeling
    
  # Output mode
  mode: stdout  # Use 'interactive' for TUI debugging mode
  
  # Artifact saving
  playbook-artifact:
    enable: true
    save-as: "/runner/ansible-artifacts/{playbook_name}-artifact-{ts_utc}.json"
  
  # Logging
  logging:
    level: info
    append: false
EOF

echo "✓ Configuration created at ~/.ansible-navigator.yaml"

# ============================================
# Step 4: Pull Execution Environment
# ============================================
echo ""
echo "[4/4] Pulling AgnosticD execution environment..."
echo "(This may take a few minutes on first run)"

podman pull quay.io/agnosticd/ee-multicloud:latest

echo ""
echo "✓ Execution environment ready"

# ============================================
# Verification
# ============================================
echo ""
echo "============================================"
echo " Verification"
echo "============================================"

# Check ansible-navigator
echo ""
echo "ansible-navigator version:"
ansible-navigator --version

# Check image
echo ""
echo "Execution environment image:"
podman images | grep agnosticd

# Test basic functionality
echo ""
echo "Testing ansible-navigator..."
if ansible-navigator --help > /dev/null 2>&1; then
    echo "✓ ansible-navigator is functional"
else
    echo "✗ ansible-navigator test failed"
    exit 1
fi

echo ""
echo "============================================"
echo " ✓ Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Configure AWS credentials: ./02-configure-aws-credentials.sh"
echo "  2. Test single SNO: ./03-test-single-sno.sh student1"
echo ""


