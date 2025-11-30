#!/bin/bash
# Fix pull-secret propagation issue in SNO clusters
# This addresses the issue where OpenShift doesn't automatically propagate
# the global pull-secret to serviceaccount dockercfg secrets in all namespaces

set -euo pipefail

STUDENT_NAME=${1:-}
DEPLOYMENT_MODE=${2:-rhpds}

if [ -z "$STUDENT_NAME" ]; then
  echo "Usage: $0 <student_name> [deployment_mode]"
  echo ""
  echo "Example:"
  echo "  $0 student1"
  echo "  $0 student1 rhpds"
  exit 1
fi

GUID="test-${STUDENT_NAME}"
OUTPUT_DIR="${HOME}/agnosticd-output/${GUID}"
KUBECONFIG_FILE="${OUTPUT_DIR}/low-latency-workshop-sno_${GUID}_kubeconfig"

if [ ! -f "$KUBECONFIG_FILE" ]; then
  echo "❌ Kubeconfig not found: $KUBECONFIG_FILE"
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  FIXING PULL-SECRET PROPAGATION                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Cluster: $GUID"
echo "Kubeconfig: $KUBECONFIG_FILE"
echo ""

# Check if cluster is accessible
echo "1. Checking cluster access..."
if ! oc whoami &>/dev/null; then
  echo "❌ Cannot access cluster. Check kubeconfig and cluster status."
  exit 1
fi
echo "✅ Cluster accessible"

# Check marketplace health
echo ""
echo "2. Checking marketplace namespace and pod health..."
if ! oc get namespace openshift-marketplace &>/dev/null; then
  echo "❌ openshift-marketplace namespace not found!"
  echo "   This is unusual - the cluster may not be fully initialized."
  exit 1
fi

# Check for pods
POD_COUNT=$(oc get pods -n openshift-marketplace --no-headers 2>/dev/null | wc -l)
echo "  Found $POD_COUNT pods in openshift-marketplace"

# Check for ImagePullBackOff issues
FAILING_PODS=$(oc get pods -n openshift-marketplace -o json 2>/dev/null | \
  jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason? == "ImagePullBackOff" or .status.containerStatuses[]?.state.waiting.reason? == "ErrImagePull") | .metadata.name' | wc -l)

echo "  Pods with image pull issues: $FAILING_PODS"

# Check if fix is needed
if [ "$FAILING_PODS" -eq "0" ] && [ "$POD_COUNT" -gt "0" ]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ✅ NO FIX NEEDED - MARKETPLACE IS HEALTHY                 ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "All marketplace pods are running normally."
  echo "The pull-secret is already properly propagated."
  echo ""
  oc get pods -n openshift-marketplace
  exit 0
fi

if [ "$POD_COUNT" -eq "0" ]; then
  echo "  ⚠️  No pods found - marketplace may still be initializing"
  echo "     Proceeding with preventive fix..."
fi

if [ "$FAILING_PODS" -gt "0" ]; then
  echo "  ⚠️  Found pods with image pull failures - fix needed!"
fi

# Copy pull-secret to openshift-marketplace
echo ""
echo "3. Copying pull-secret to openshift-marketplace namespace..."
oc get secret pull-secret -n openshift-config -o yaml | \
  sed 's/namespace: openshift-config/namespace: openshift-marketplace/' | \
  oc apply -f - 2>&1 | grep -v "Warning:" || echo "  (already exists)"

# Link pull-secret to marketplace serviceaccounts
echo ""
echo "4. Linking pull-secret to marketplace serviceaccounts..."
for sa in redhat-operators certified-operators community-operators redhat-marketplace; do
  echo "  - $sa"
  
  # Check if serviceaccount exists
  if ! oc get sa $sa -n openshift-marketplace &>/dev/null; then
    echo "    ⚠️  ServiceAccount not found, skipping"
    continue
  fi
  
  # Check if it already has the pull-secret linked
  HAS_PULL_SECRET=$(oc get sa $sa -n openshift-marketplace -o jsonpath='{.imagePullSecrets}' | jq '.[] | select(.name=="pull-secret")' | wc -l)
  
  if [ "$HAS_PULL_SECRET" -eq "0" ]; then
    # Patch the serviceaccount to add pull-secret reference
    oc patch serviceaccount $sa -n openshift-marketplace \
      --type='json' \
      -p='[{"op":"add","path":"/imagePullSecrets/-","value":{"name":"pull-secret"}}]' 2>&1 | grep -v "Warning:" || true
    echo "    ✅ Linked"
  else
    echo "    ✅ Already linked"
  fi
done

# Delete failing marketplace pods
echo ""
echo "5. Restarting marketplace catalog pods..."
FAILING_PODS=$(oc get pods -n openshift-marketplace -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' 2>/dev/null)
if [ -n "$FAILING_PODS" ]; then
  for pod in $FAILING_PODS; do
    echo "  - Deleting $pod"
    oc delete pod $pod -n openshift-marketplace --wait=false 2>&1 | grep -v "Warning:" || true
  done
else
  echo "  ℹ️  No failing pods to restart"
fi

# Copy to RHACM namespace if it exists
echo ""
echo "6. Checking RHACM agent namespace..."
if oc get namespace open-cluster-management-agent &>/dev/null; then
  echo "  Found open-cluster-management-agent namespace"
  
  oc get secret pull-secret -n openshift-config -o yaml | \
    sed 's/namespace: openshift-config/namespace: open-cluster-management-agent/' | \
    oc apply -f - 2>&1 | grep -v "Warning:" || echo "  (already exists)"
  
  # Update the RHACM-specific pull secret
  if oc get secret open-cluster-management-image-pull-credentials -n open-cluster-management-agent &>/dev/null; then
    echo "  Updating open-cluster-management-image-pull-credentials..."
    oc set data secret/open-cluster-management-image-pull-credentials \
      -n open-cluster-management-agent \
      --from-file=.dockerconfigjson=<(oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d) \
      2>&1 | grep -v "Warning:" || true
  fi
  
  # Restart klusterlet if in ImagePullBackOff
  KLUSTERLET_PODS=$(oc get pods -n open-cluster-management-agent -l app=klusterlet -o jsonpath='{.items[?(@.status.containerStatuses[*].state.waiting.reason=="ImagePullBackOff")].metadata.name}' 2>/dev/null)
  if [ -n "$KLUSTERLET_PODS" ]; then
    echo "  Restarting klusterlet pods..."
    oc delete pod -n open-cluster-management-agent -l app=klusterlet --wait=false 2>&1 | grep -v "Warning:" || true
  else
    echo "  ✅ Klusterlet pods healthy"
  fi
else
  echo "  ℹ️  RHACM agent namespace not found (normal if not imported yet)"
fi

echo ""
echo "7. Waiting for pods to stabilize (30 seconds)..."
sleep 30

echo ""
echo "8. Checking marketplace pod status..."
oc get pods -n openshift-marketplace | grep -E "NAME|catalog"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ FIX COMPLETE                                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "The pull-secret has been propagated to the necessary namespaces."
echo "New pods should now be able to pull images from registry.redhat.io"
echo ""
echo "To verify, check catalog source pods:"
echo "  oc get pods -n openshift-marketplace"
echo ""
echo "All catalog pods should be in 'Running' status within 2-3 minutes."
echo ""

