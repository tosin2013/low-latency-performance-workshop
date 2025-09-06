#!/bin/bash

# validate-rhacm.sh
# Script to validate RHACM installation and configuration for the workshop
# Confidence: 95% - Based on RHACM best practices and workshop requirements

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're connected to an OpenShift cluster
    if ! oc whoami &> /dev/null; then
        log_error "Not logged into an OpenShift cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate RHACM Operator installation
validate_rhacm_operator() {
    log_info "Validating RHACM Operator installation..."
    
    # Check if operator is installed
    if ! oc get csv -n open-cluster-management | grep -q "advanced-cluster-management"; then
        log_error "RHACM Operator is not installed"
        return 1
    fi

    # Check operator status
    local operator_phase
    operator_phase=$(oc get csv -n open-cluster-management -o jsonpath='{.items[?(@.spec.displayName=="Advanced Cluster Management for Kubernetes")].status.phase}' 2>/dev/null || echo "NotFound")
    
    if [[ "$operator_phase" != "Succeeded" ]]; then
        log_error "RHACM Operator is not in Succeeded phase: $operator_phase"
        return 1
    fi
    
    # Check operator version
    local operator_version
    operator_version=$(oc get csv -n open-cluster-management -o jsonpath='{.items[?(@.spec.displayName=="Advanced Cluster Management for Kubernetes")].spec.version}' 2>/dev/null || echo "Unknown")
    log_success "RHACM Operator is installed and running (version: $operator_version)"
}

# Validate MultiClusterHub instance
validate_multiclusterhub() {
    log_info "Validating MultiClusterHub instance..."
    
    # Check if MultiClusterHub exists
    if ! oc get multiclusterhub multiclusterhub -n open-cluster-management &> /dev/null; then
        log_error "MultiClusterHub 'multiclusterhub' not found in open-cluster-management namespace"
        return 1
    fi
    
    # Check MultiClusterHub status
    local mch_phase
    mch_phase=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [[ "$mch_phase" != "Running" ]]; then
        log_error "MultiClusterHub phase is: $mch_phase (expected: Running)"
        return 1
    fi
    
    # Check version
    local mch_version
    mch_version=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.status.currentVersion}' 2>/dev/null || echo "Unknown")
    
    # Check availability config
    local availability_config
    availability_config=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.spec.availabilityConfig}' 2>/dev/null || echo "Unknown")
    
    log_success "MultiClusterHub is Running (version: $mch_version, availability: $availability_config)"
}

# Validate MultiCluster Engine
validate_multicluster_engine() {
    log_info "Validating MultiCluster Engine..."
    
    # Check if MCE exists
    if ! oc get multiclusterengine -n multicluster-engine &> /dev/null; then
        log_error "MultiCluster Engine not found"
        return 1
    fi
    
    # Check MCE status
    local mce_status
    mce_status=$(oc get multiclusterengine -n multicluster-engine -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
    
    if [[ "$mce_status" != "Available" ]]; then
        log_error "MultiCluster Engine status is: $mce_status (expected: Available)"
        return 1
    fi
    
    # Check version
    local mce_version
    mce_version=$(oc get multiclusterengine -n multicluster-engine -o jsonpath='{.items[0].status.currentVersion}' 2>/dev/null || echo "Unknown")
    
    log_success "MultiCluster Engine is Available (version: $mce_version)"
}

# Validate managed clusters
validate_managed_clusters() {
    log_info "Validating managed clusters..."
    
    # Check if local cluster is managed
    if oc get managedcluster local-cluster &> /dev/null; then
        local local_status
        local_status=$(oc get managedcluster local-cluster -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$local_status" == "True" ]]; then
            log_success "Local cluster is managed and available"
        else
            log_warning "Local cluster status: $local_status"
        fi
    else
        log_warning "Local cluster is not managed"
    fi
    
    # List all managed clusters
    local cluster_count
    cluster_count=$(oc get managedclusters --no-headers 2>/dev/null | wc -l || echo "0")
    log_info "Total managed clusters: $cluster_count"
    
    if [[ $cluster_count -gt 0 ]]; then
        log_info "Managed clusters:"
        oc get managedclusters -o custom-columns="NAME:.metadata.name,HUB ACCEPTED:.spec.hubAcceptsClient,AVAILABLE:.status.conditions[?(@.type=='ManagedClusterConditionAvailable')].status,JOINED:.status.conditions[?(@.type=='ManagedClusterJoined')].status" --no-headers 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi
}

# Validate RHACM components
validate_rhacm_components() {
    log_info "Validating RHACM components..."
    
    # Check key components in open-cluster-management namespace
    local components=("multiclusterhub-operator" "console-chart-console-v2" "grc-policy-propagator" "search-api")
    
    for component in "${components[@]}"; do
        if oc get deployment "$component" -n open-cluster-management &> /dev/null; then
            local ready_replicas
            ready_replicas=$(oc get deployment "$component" -n open-cluster-management -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas
            desired_replicas=$(oc get deployment "$component" -n open-cluster-management -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$ready_replicas" == "$desired_replicas" ]]; then
                log_success "$component: $ready_replicas/$desired_replicas replicas ready"
            else
                log_warning "$component: $ready_replicas/$desired_replicas replicas ready"
            fi
        else
            log_warning "Component $component not found"
        fi
    done
    
    # Check MCE components
    local mce_components=("cluster-manager" "multicluster-engine-operator")
    
    for component in "${mce_components[@]}"; do
        if oc get deployment "$component" -n multicluster-engine &> /dev/null; then
            local ready_replicas
            ready_replicas=$(oc get deployment "$component" -n multicluster-engine -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas
            desired_replicas=$(oc get deployment "$component" -n multicluster-engine -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$ready_replicas" == "$desired_replicas" ]]; then
                log_success "$component: $ready_replicas/$desired_replicas replicas ready"
            else
                log_warning "$component: $ready_replicas/$desired_replicas replicas ready"
            fi
        else
            log_warning "MCE component $component not found"
        fi
    done
}

# Validate RHACM console access
validate_console_access() {
    log_info "Validating RHACM console access..."

    # Check if RHACM console route exists (standalone)
    if oc get route multicloud-console -n open-cluster-management &> /dev/null; then
        local console_url
        console_url=$(oc get route multicloud-console -n open-cluster-management -o jsonpath='{.spec.host}' 2>/dev/null || echo "unknown")
        log_success "RHACM Console available at: https://$console_url"
    else
        # Check if integrated with OpenShift console (newer versions)
        if oc get route console -n openshift-console &> /dev/null; then
            local console_url
            console_url=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}' 2>/dev/null || echo "unknown")
            log_success "RHACM Console integrated with OpenShift Console at: https://$console_url"
            log_info "Access RHACM features through the OpenShift Console -> All Clusters"
        else
            log_warning "No console access found"
        fi
    fi
}

# Main validation function
main() {
    log_info "Starting RHACM validation for workshop environment..."
    echo "=================================================="
    
    local exit_code=0
    
    check_prerequisites || exit_code=1
    validate_rhacm_operator || exit_code=1
    validate_multiclusterhub || exit_code=1
    validate_multicluster_engine || exit_code=1
    validate_managed_clusters || exit_code=1
    validate_rhacm_components || exit_code=1
    validate_console_access || exit_code=1
    
    echo "=================================================="
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All RHACM validations passed!"
        log_info "RHACM is properly configured for the workshop environment."
    else
        log_error "Some validations failed. Please review the output above."
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
