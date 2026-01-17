#!/bin/bash
# -------------------------------------------------------------------
# Validate SNO Development Cluster
#
# Runs validation checks on a deployed SNO cluster to verify:
#   - OpenShift Virtualization operator status
#   - KVM emulation configuration (for virtualized instances)
#   - Test VM creation and boot
#   - Cert Manager operator status
#   - Node health
#
# Usage:
#   ./validate-sno-dev.sh [GUID] [INSTANCE_TYPE]
#
# Examples:
#   ./validate-sno-dev.sh dev1 virtualized
#   ./validate-sno-dev.sh dev1 baremetal
# -------------------------------------------------------------------

set -euo pipefail

GUID="${1:-dev1}"
INSTANCE_TYPE="${2:-virtualized}"

# Paths
DEVELOPMENT_DIR="${HOME}/Development"
KUBECONFIG_PATH="${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeconfig"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo -e "${RED}Error: Kubeconfig not found at $KUBECONFIG_PATH${NC}"
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

# Check if oc is available
if ! command -v oc &> /dev/null; then
  echo -e "${RED}Error: oc command not found${NC}"
  exit 1
fi

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}SNO Development Cluster Validation${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "GUID:          $GUID"
echo "Instance:     $INSTANCE_TYPE"
echo ""

# Wait for API to be available
echo -e "${CYAN}Waiting for API to be available...${NC}"
for i in {1..30}; do
  if oc get nodes &>/dev/null; then
    break
  fi
  sleep 2
done

if ! oc get nodes &>/dev/null; then
  echo -e "${RED}Error: Cannot connect to cluster API${NC}"
  exit 1
fi

echo -e "${GREEN}✓${NC} Connected to cluster"
echo ""

# Apply validation job
VALIDATION_JOB="${WORKSHOP_DIR}/gitops/validation-workload/validation-job.yaml"

if [[ ! -f "$VALIDATION_JOB" ]]; then
  echo -e "${RED}Error: Validation job manifest not found at $VALIDATION_JOB${NC}"
  exit 1
fi

echo -e "${CYAN}Applying validation job...${NC}"
oc apply -f "$VALIDATION_JOB"

echo ""
echo -e "${CYAN}Waiting for validation job to complete (max 5 minutes)...${NC}"

# Wait for job to complete
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  JOB_STATUS=$(oc get job sno-validation -n default -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "Unknown")
  if [ "$JOB_STATUS" = "True" ]; then
    echo -e "${GREEN}✓${NC} Validation job completed"
    break
  fi
  
  FAILED=$(oc get job sno-validation -n default -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "False")
  if [ "$FAILED" = "True" ]; then
    echo -e "${RED}✗${NC} Validation job failed"
    break
  fi
  
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  echo -n "."
done

echo ""
echo ""

# Get validation results
if oc get configmap sno-validation-results -n default &>/dev/null; then
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}Validation Results${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo ""
  
  oc get configmap sno-validation-results -n default -o yaml | grep -A 100 "^data:" | sed 's/^data://' | sed 's/^  //'
  
  PASSED=$(oc get configmap sno-validation-results -n default -o jsonpath='{.data.passed}' 2>/dev/null || echo "0")
  FAILED=$(oc get configmap sno-validation-results -n default -o jsonpath='{.data.failed}' 2>/dev/null || echo "0")
  WARNINGS=$(oc get configmap sno-validation-results -n default -o jsonpath='{.data.warnings}' 2>/dev/null || echo "0")
  
  echo ""
  echo -e "${GREEN}Passed:${NC} $PASSED"
  echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
  echo -e "${RED}Failed:${NC} $FAILED"
  echo ""
  
  if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Validation completed with $FAILED failure(s)${NC}"
    echo ""
    echo "Check job logs for details:"
    echo "  oc logs job/sno-validation -n default"
    exit 1
  else
    echo -e "${GREEN}All validation checks passed!${NC}"
    exit 0
  fi
else
  echo -e "${YELLOW}⚠${NC}  Validation results not found"
  echo "   Check job status:"
  echo "   oc get job sno-validation -n default"
  echo "   oc logs job/sno-validation -n default"
  exit 1
fi
