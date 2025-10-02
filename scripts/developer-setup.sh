#!/bin/bash
# Developer Setup Script for Low-Latency Performance Workshop
# This script helps new developers set up their development environment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_section() {
    echo ""
    echo "=================================================="
    echo -e "${CYAN}$1${NC}"
    echo "=================================================="
    echo ""
}

# Check if running in the correct directory
check_directory() {
    if [ ! -f "DEVELOPER_GUIDE.md" ] || [ ! -d "content" ]; then
        log_error "This script must be run from the workshop repository root"
        exit 1
    fi
}

# Welcome message
show_welcome() {
    clear
    echo ""
    echo "=================================================="
    echo -e "${CYAN}Welcome to the Low-Latency Performance Workshop${NC}"
    echo -e "${CYAN}Developer Setup Script${NC}"
    echo "=================================================="
    echo ""
    echo "This script will help you set up your development"
    echo "environment for contributing to the workshop."
    echo ""
    read -p "Press Enter to continue..."
}

# Check system prerequisites
check_prerequisites() {
    log_section "Checking System Prerequisites"
    
    local missing_tools=()
    local optional_tools=()
    
    # Required tools
    log_info "Checking required tools..."
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    else
        log_success "git: $(git --version)"
    fi
    
    if ! command -v node &> /dev/null; then
        missing_tools+=("node")
    else
        log_success "node: $(node --version)"
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    else
        log_success "npm: $(npm --version)"
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    else
        log_success "python3: $(python3 --version)"
    fi
    
    # Optional but recommended tools
    echo ""
    log_info "Checking optional tools..."
    
    if ! command -v asciidoctor &> /dev/null; then
        optional_tools+=("asciidoctor")
        log_warning "asciidoctor not found (recommended for AsciiDoc validation)"
    else
        log_success "asciidoctor: $(asciidoctor --version | head -n1)"
    fi
    
    if ! command -v yamllint &> /dev/null; then
        optional_tools+=("yamllint")
        log_warning "yamllint not found (required for YAML validation)"
    else
        log_success "yamllint: $(yamllint --version)"
    fi
    
    if ! command -v oc &> /dev/null; then
        optional_tools+=("oc")
        log_warning "oc (OpenShift CLI) not found (needed for testing)"
    else
        log_success "oc: $(oc version --client | head -n1)"
    fi
    
    # Report missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo ""
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        log_info "Installation instructions:"
        log_info "  - git: https://git-scm.com/downloads"
        log_info "  - node/npm: https://nodejs.org/"
        log_info "  - python3: https://www.python.org/downloads/"
        echo ""
        return 1
    fi
    
    if [ ${#optional_tools[@]} -gt 0 ]; then
        echo ""
        log_warning "Optional tools not found: ${optional_tools[*]}"
        echo ""
        read -p "Would you like to install optional tools? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_optional_tools
        fi
    fi
    
    return 0
}

# Install optional tools
install_optional_tools() {
    log_section "Installing Optional Tools"
    
    # Install yamllint
    if ! command -v yamllint &> /dev/null; then
        log_info "Installing yamllint..."
        if pip3 install --user yamllint; then
            log_success "yamllint installed"
        else
            log_warning "Failed to install yamllint - you may need to install it manually"
        fi
    fi
    
    # Install asciidoctor
    if ! command -v asciidoctor &> /dev/null; then
        log_info "Installing asciidoctor..."
        if command -v gem &> /dev/null; then
            if gem install asciidoctor; then
                log_success "asciidoctor installed"
            else
                log_warning "Failed to install asciidoctor - you may need to install it manually"
            fi
        else
            log_warning "Ruby gem not found - cannot install asciidoctor"
            log_info "Install Ruby and try again, or install asciidoctor manually"
        fi
    fi
    
    # Install markdownlint
    if ! command -v markdownlint &> /dev/null; then
        log_info "Installing markdownlint-cli..."
        if npm install -g markdownlint-cli 2>/dev/null; then
            log_success "markdownlint-cli installed"
        else
            log_warning "Failed to install markdownlint-cli - you may need sudo access"
        fi
    fi
}

# Install Node.js dependencies
install_node_dependencies() {
    log_section "Installing Node.js Dependencies"
    
    if [ -f "package.json" ]; then
        log_info "Installing npm packages..."
        if npm install; then
            log_success "Node.js dependencies installed"
        else
            log_error "Failed to install Node.js dependencies"
            return 1
        fi
    else
        log_warning "No package.json found"
    fi
    
    return 0
}

# Set up git hooks
setup_git_hooks() {
    log_section "Setting Up Git Hooks"
    
    log_info "Configuring git to use custom hooks directory..."
    
    # Configure git to use .githooks directory
    if git config core.hooksPath .githooks; then
        log_success "Git hooks directory configured"
    else
        log_error "Failed to configure git hooks directory"
        return 1
    fi
    
    # Make hooks executable
    if [ -d ".githooks" ]; then
        log_info "Making git hooks executable..."
        chmod +x .githooks/*
        log_success "Git hooks are now executable"
    fi
    
    # Make validation script executable
    if [ -f "scripts/validate-documents.sh" ]; then
        chmod +x scripts/validate-documents.sh
        log_success "Document validation script is executable"
    fi
    
    log_success "Pre-commit hooks configured successfully!"
    log_info "Documents will be validated automatically before each commit"
    
    return 0
}

# Create local development configuration
create_dev_config() {
    log_section "Creating Development Configuration"
    
    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        log_info "Creating .env file..."
        cat > .env << 'EOF'
# Local Development Environment Configuration
# Copy this file and customize for your environment

# Workshop GUID (if testing with actual environment)
WORKSHOP_GUID=your-guid-here

# OpenShift Cluster Details
CLUSTER_API=https://api.cluster-${WORKSHOP_GUID}.dynamic.redhatworkshops.io:6443
CLUSTER_CONSOLE=https://console-openshift-console.apps.cluster-${WORKSHOP_GUID}.dynamic.redhatworkshops.io

# SSH Access
BASTION_HOST=bastion.${WORKSHOP_GUID}.dynamic.redhatworkshops.io
SSH_USER=ec2-user

# Development Settings
DEV_MODE=true
EOF
        log_success ".env file created"
        log_info "Edit .env file with your workshop GUID and settings"
    else
        log_info ".env file already exists"
    fi
}

# Show next steps
show_next_steps() {
    log_section "Setup Complete!"
    
    echo "Your development environment is ready! 🎉"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Read the Developer Guide:"
    echo "   ${CYAN}cat DEVELOPER_GUIDE.md${NC}"
    echo ""
    echo "2. Build the documentation locally:"
    echo "   ${CYAN}make build${NC}"
    echo ""
    echo "3. Serve the documentation:"
    echo "   ${CYAN}make serve${NC}"
    echo ""
    echo "4. Run tests:"
    echo "   ${CYAN}npm test${NC}"
    echo ""
    echo "5. Validate documents manually:"
    echo "   ${CYAN}./scripts/validate-documents.sh${NC}"
    echo ""
    echo "6. Make your changes and commit:"
    echo "   ${CYAN}git add .${NC}"
    echo "   ${CYAN}git commit -m \"Your message\"${NC}"
    echo "   ${GREEN}(Documents will be validated automatically)${NC}"
    echo ""
    echo "Useful commands:"
    echo "  ${CYAN}make help${NC}           - Show all available make targets"
    echo "  ${CYAN}make clean-build${NC}    - Clean and rebuild documentation"
    echo "  ${CYAN}make stop${NC}           - Stop the local server"
    echo ""
    echo "Documentation:"
    echo "  - Developer Guide: DEVELOPER_GUIDE.md"
    echo "  - Environment Config: ENVIRONMENT_CONFIG.md"
    echo "  - Contributing: See DEVELOPER_GUIDE.md"
    echo ""
    echo "Need help? Check the documentation or open an issue!"
    echo ""
}

# Main execution
main() {
    check_directory
    show_welcome
    
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    install_node_dependencies
    setup_git_hooks
    create_dev_config
    show_next_steps
    
    log_success "Developer setup completed successfully!"
}

# Run main function
main "$@"

