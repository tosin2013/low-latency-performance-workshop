#!/bin/bash

# validate-argocd-security.sh
# Script to validate default ArgoCD security configuration in OpenShift environment
# Note: Validates the default OpenShift GitOps ArgoCD instance
# Confidence: 95% - Based on OpenShift GitOps best practices and security requirements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if required tools are available
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're connected to an OpenShift cluster
    if ! oc whoami &> /dev/null; then
        log_error "Not logged into an OpenShift cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate OpenShift GitOps Operator installation
validate_operator() {
    log_info "Validating OpenShift GitOps Operator installation..."
    
    # Check if operator is installed
    if ! oc get csv -n openshift-gitops | grep -q "openshift-gitops-operator"; then
        log_error "OpenShift GitOps Operator is not installed"
        return 1
    fi

    # Check operator status
    local operator_phase
    operator_phase=$(oc get csv -n openshift-gitops -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift GitOps")].status.phase}' 2>/dev/null || echo "NotFound")
    
    if [[ "$operator_phase" != "Succeeded" ]]; then
        log_error "OpenShift GitOps Operator is not in Succeeded phase: $operator_phase"
        return 1
    fi
    
    log_success "OpenShift GitOps Operator is installed and running"
}

# Validate ArgoCD instance
validate_argocd_instance() {
    log_info "Validating ArgoCD instance configuration..."
    
    # Check if ArgoCD instance exists
    if ! oc get argocd openshift-gitops -n openshift-gitops &> /dev/null; then
        log_error "Default ArgoCD instance 'openshift-gitops' not found in openshift-gitops namespace"
        return 1
    fi

    # Check ArgoCD phase
    local argocd_phase
    argocd_phase=$(oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [[ "$argocd_phase" != "Available" ]]; then
        log_warning "ArgoCD instance phase is: $argocd_phase (expected: Available)"
    else
        log_success "ArgoCD instance is Available"
    fi
}

# Validate security contexts
validate_security_contexts() {
    log_info "Validating security contexts..."
    
    local components=("openshift-gitops-server" "openshift-gitops-application-controller" "openshift-gitops-repo-server" "openshift-gitops-redis")

    for component in "${components[@]}"; do
        log_info "Checking security context for $component..."

        # Check if deployment/statefulset exists
        local resource_type="deployment"
        if [[ "$component" == *"application-controller"* ]]; then
            resource_type="statefulset"
        fi

        if ! oc get $resource_type "$component" -n openshift-gitops &> /dev/null; then
            log_warning "$resource_type $component not found"
            continue
        fi

        # Check runAsNonRoot
        local run_as_non_root
        run_as_non_root=$(oc get $resource_type "$component" -n openshift-gitops -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "false")

        if [[ "$run_as_non_root" != "true" ]]; then
            log_warning "$component: runAsNonRoot is not explicitly set to true (may be using SCC defaults)"
        else
            log_success "$component: runAsNonRoot is correctly set"
        fi

        # Check container security context
        local allow_privilege_escalation
        allow_privilege_escalation=$(oc get $resource_type "$component" -n openshift-gitops -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || echo "not_set")

        if [[ "$allow_privilege_escalation" != "false" ]]; then
            log_warning "$component: allowPrivilegeEscalation is not explicitly set to false (may be using SCC defaults)"
        else
            log_success "$component: allowPrivilegeEscalation is correctly set"
        fi

        # Check if running with restricted SCC
        local pod_name
        pod_name=$(oc get pods -n openshift-gitops -l app.kubernetes.io/name=$component -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [[ -n "$pod_name" ]]; then
            local scc
            scc=$(oc get pod "$pod_name" -n openshift-gitops -o jsonpath='{.metadata.annotations.openshift\.io/scc}' 2>/dev/null || echo "unknown")

            if [[ "$scc" == "restricted-v2" || "$scc" == "restricted" ]]; then
                log_success "$component: Running with restricted SCC ($scc)"
            else
                log_warning "$component: Running with SCC: $scc (not restricted)"
            fi
        fi
    done
}

# Validate RBAC configuration
validate_rbac() {
    log_info "Validating RBAC configuration..."
    
    # Check default service account
    if oc get serviceaccount openshift-gitops-argocd-application-controller -n openshift-gitops &> /dev/null; then
        log_success "Default ArgoCD application controller service account exists"
    else
        log_error "Default ArgoCD application controller service account not found"
    fi

    # Check default cluster role
    if oc get clusterrole openshift-gitops-openshift-gitops-argocd-application-controller &> /dev/null; then
        log_success "Default ArgoCD application controller ClusterRole exists"
    else
        log_error "Default ArgoCD application controller ClusterRole not found"
    fi

    # Check workshop additional permissions
    if oc get clusterrole workshop-additional-permissions &> /dev/null; then
        log_success "Workshop additional permissions ClusterRole exists"
    else
        log_warning "Workshop additional permissions ClusterRole not found"
    fi

    if oc get clusterrolebinding workshop-additional-permissions &> /dev/null; then
        log_success "Workshop additional permissions ClusterRoleBinding exists"
    else
        log_warning "Workshop additional permissions ClusterRoleBinding not found"
    fi
}

# Validate OpenShift Route
validate_route() {
    log_info "Validating OpenShift Route configuration..."
    
    if oc get route openshift-gitops-server -n openshift-gitops &> /dev/null; then
        local tls_termination
        tls_termination=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.tls.termination}' 2>/dev/null || echo "none")

        if [[ "$tls_termination" == "reencrypt" ]]; then
            log_success "Route TLS termination is correctly set to reencrypt"
        else
            log_error "Route TLS termination is not set to reencrypt: $tls_termination"
        fi

        local route_url
        route_url=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "unknown")
        log_info "ArgoCD UI available at: https://$route_url"
    else
        log_error "ArgoCD server route not found"
    fi
}

# Main validation function
main() {
    log_info "Starting ArgoCD security validation for OpenShift environment..."
    echo "=================================================="
    
    local exit_code=0
    
    check_prerequisites || exit_code=1
    validate_operator || exit_code=1
    validate_argocd_instance || exit_code=1
    validate_security_contexts || exit_code=1
    validate_rbac || exit_code=1
    validate_route || exit_code=1
    
    echo "=================================================="
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All ArgoCD security validations passed!"
        log_info "The default OpenShift GitOps ArgoCD instance is properly configured for the workshop."
    else
        log_error "Some validations failed. Please review the output above."
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
