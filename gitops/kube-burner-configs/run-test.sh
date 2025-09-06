#!/bin/bash

# Kube-burner Test Runner Script
# Usage: ./run-test.sh <test-type>
# Example: ./run-test.sh baseline

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
WORKLOADS_DIR="${SCRIPT_DIR}/workloads"

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

# Usage function
usage() {
    echo "Usage: $0 <test-type>"
    echo ""
    echo "Available test types:"
    echo "  baseline    - Run baseline performance test (standard pods)"
    echo "  tuned-pod   - Run tuned pod performance test (isolated CPUs)"
    echo "  tuned-vmi   - Run tuned VMI performance test (low-latency VMs)"
    echo ""
    echo "Examples:"
    echo "  $0 baseline"
    echo "  $0 tuned-pod"
    echo "  $0 tuned-vmi"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kube-burner is installed
    if ! command -v kube-burner &> /dev/null; then
        log_error "kube-burner is not installed or not in PATH"
        log_info "Please install kube-burner first: https://kube-burner.github.io/kube-burner/latest/installation/"
        exit 1
    fi
    
    # Check if oc/kubectl is available
    if ! command -v oc &> /dev/null && ! command -v kubectl &> /dev/null; then
        log_error "Neither 'oc' nor 'kubectl' is available"
        log_info "Please install OpenShift CLI or kubectl"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! oc whoami &> /dev/null && ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes/OpenShift cluster"
        log_info "Please ensure you are logged in to your cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Run kube-burner test
run_test() {
    local test_type="$1"
    local config_file="${CONFIG_DIR}/${test_type}.yml"
    
    log_info "Running ${test_type} performance test..."
    
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    # Display test configuration
    log_info "Test configuration:"
    echo "  - Config file: $config_file"
    echo "  - Workloads directory: $WORKLOADS_DIR"
    echo ""
    
    # Run kube-burner
    log_info "Executing kube-burner..."
    if kube-burner init -c "$config_file" --log-level=info; then
        log_success "Test completed successfully!"
        
        # Show results location
        local metrics_dir
        case "$test_type" in
            "baseline")
                metrics_dir="collected-metrics"
                ;;
            "tuned-pod")
                metrics_dir="collected-metrics-tuned"
                ;;
            "tuned-vmi")
                metrics_dir="collected-metrics-vmi"
                ;;
        esac
        
        if [[ -d "$metrics_dir" ]]; then
            log_info "Results saved to: $metrics_dir"
            log_info "Available metrics files:"
            ls -la "$metrics_dir"
        fi
    else
        log_error "Test failed!"
        exit 1
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        log_error "Invalid number of arguments"
        usage
    fi
    
    local test_type="$1"
    
    # Validate test type
    case "$test_type" in
        "baseline"|"tuned-pod"|"tuned-vmi")
            ;;
        *)
            log_error "Invalid test type: $test_type"
            usage
            ;;
    esac
    
    log_info "Starting kube-burner test runner..."
    log_info "Test type: $test_type"
    echo ""
    
    check_prerequisites
    run_test "$test_type"
    
    log_success "Test runner completed!"
}

# Run main function
main "$@"
