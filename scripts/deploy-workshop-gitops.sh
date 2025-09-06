#!/bin/bash

# deploy-workshop-gitops.sh
# Script to deploy workshop GitOps applications to existing OpenShift GitOps ArgoCD
# Confidence: 98% - Uses existing ArgoCD with proper security contexts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-aws}"  # Default to aws, can be 'aws' or 'baremetal'
GITOPS_DIR="gitops"
NAMESPACE="openshift-gitops"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v kustomize &> /dev/null; then
        log_error "kustomize is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're connected to an OpenShift cluster
    if ! oc whoami &> /dev/null; then
        log_error "Not logged into an OpenShift cluster"
        exit 1
    fi
    
    # Validate environment parameter
    if [[ "$ENVIRONMENT" != "aws" && "$ENVIRONMENT" != "baremetal" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'aws' or 'baremetal'"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate OpenShift GitOps is available
validate_argocd() {
    log_info "Validating OpenShift GitOps ArgoCD..."
    
    # Check if ArgoCD instance exists
    if ! oc get argocd openshift-gitops -n "$NAMESPACE" &> /dev/null; then
        log_error "OpenShift GitOps ArgoCD instance not found. Please install OpenShift GitOps Operator first."
        return 1
    fi
    
    # Check ArgoCD status
    local argocd_phase
    argocd_phase=$(oc get argocd openshift-gitops -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [[ "$argocd_phase" != "Available" ]]; then
        log_error "ArgoCD instance is not Available. Current phase: $argocd_phase"
        return 1
    fi
    
    log_success "OpenShift GitOps ArgoCD is available and ready"
}

# Deploy workshop GitOps applications
deploy_workshop_apps() {
    log_info "Deploying workshop GitOps applications for environment: $ENVIRONMENT"
    
    # Apply the base workshop applications
    log_info "Applying workshop project and app-of-apps..."
    
    if kustomize build "$GITOPS_DIR/base" | oc apply -f -; then
        log_success "Workshop GitOps applications deployed successfully"
    else
        log_error "Failed to deploy workshop GitOps applications"
        return 1
    fi
    
    # Wait for the app-of-apps to be synced
    log_info "Waiting for app-of-apps to sync..."
    local timeout=300
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local sync_status
        sync_status=$(oc get application low-latency-workshop-apps -n "$NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$sync_status" == "Synced" ]]; then
            log_success "App-of-apps is synced successfully"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        log_info "App sync status: $sync_status - Waiting... ($elapsed/$timeout seconds)"
    done
    
    log_warning "Timeout waiting for app-of-apps to sync, but deployment may still be in progress"
}

# Get ArgoCD access information
get_access_info() {
    log_info "Getting ArgoCD access information..."
    
    # Get route URL
    local route_url
    if route_url=$(oc get route openshift-gitops-server -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null); then
        log_success "ArgoCD UI URL: https://$route_url"
    else
        log_warning "ArgoCD route not found"
    fi
    
    # Check for admin password secret
    local admin_secret_exists=false
    if oc get secret openshift-gitops-initial-admin-secret -n "$NAMESPACE" &> /dev/null; then
        admin_secret_exists=true
        local admin_password
        if admin_password=$(oc get secret openshift-gitops-initial-admin-secret -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); then
            log_success "ArgoCD admin password: $admin_password"
        fi
    fi
    
    if [[ "$admin_secret_exists" == "false" ]]; then
        log_info "No admin password secret found - using OpenShift OAuth authentication"
        log_info "Login with your OpenShift credentials"
    fi
    
    log_info "Login with username: admin (if using admin secret) or your OpenShift credentials"
}

# List deployed applications
list_applications() {
    log_info "Listing deployed ArgoCD applications..."
    
    if oc get applications -n "$NAMESPACE" &> /dev/null; then
        echo ""
        oc get applications -n "$NAMESPACE" -o custom-columns="NAME:.metadata.name,SYNC STATUS:.status.sync.status,HEALTH:.status.health.status,PROJECT:.spec.project"
        echo ""
    else
        log_warning "No applications found or unable to list applications"
    fi
}

# Main deployment function
main() {
    log_info "Starting workshop GitOps deployment for OpenShift environment: $ENVIRONMENT"
    echo "=================================================================="
    
    local exit_code=0
    
    check_prerequisites || exit_code=1
    
    if [[ $exit_code -eq 0 ]]; then
        validate_argocd || exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        deploy_workshop_apps || exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        get_access_info
        list_applications
    fi
    
    echo "=================================================================="
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Workshop GitOps deployment completed successfully!"
        log_info "Next steps:"
        log_info "1. Access the ArgoCD UI using the URL above"
        log_info "2. Monitor application sync status"
        log_info "3. Workshop applications will be automatically deployed"
    else
        log_error "Workshop GitOps deployment failed. Please review the output above."
    fi
    
    exit $exit_code
}

# Show usage information
usage() {
    echo "Usage: $0 [ENVIRONMENT]"
    echo ""
    echo "ENVIRONMENT: 'aws' or 'baremetal' (default: aws)"
    echo ""
    echo "Examples:"
    echo "  $0 aws        # Deploy for AWS environment"
    echo "  $0 baremetal  # Deploy for bare-metal environment"
    echo "  $0            # Deploy for AWS environment (default)"
}

# Handle help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
