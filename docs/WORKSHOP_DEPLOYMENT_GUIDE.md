# Workshop Deployment Guide - Multi-Cluster Setup

## Overview

This guide provides step-by-step instructions for properly deploying the Low-Latency Performance Workshop using the recommended multi-cluster architecture with RHACM.

## Architecture Requirements

The workshop requires a **two-cluster architecture** for safety and enterprise best practices:

### Hub Cluster (Management)
- **Purpose**: RHACM management, GitOps orchestration, workshop coordination
- **Components**: RHACM 2.14+, OpenShift GitOps, workshop content
- **Role**: Manages and deploys to target clusters
- **Safety**: No performance tuning applied here

### Target Cluster (Performance Testing)
- **Purpose**: Performance tuning, workload testing, kernel modifications
- **Components**: Node Tuning Operator, SR-IOV, OpenShift Virtualization
- **Role**: Receives performance configurations via GitOps
- **Safety**: Isolated environment for potentially disruptive changes

## Prerequisites

### Hub Cluster Requirements
- OpenShift 4.19+ cluster with cluster-admin access
- Minimum 16 vCPU, 32GB RAM for RHACM components
- Internet connectivity for operator installations
- DNS resolution for target cluster APIs

### Target Cluster Requirements  
- Single Node OpenShift (SNO) 4.19+ recommended
- Bare metal or VM with performance capabilities
- Minimum 8 vCPU, 16GB RAM, 100GB storage
- Network connectivity to hub cluster
- Suitable for kernel modifications and reboots

## Environment Assessment Template

For workshop facilitators and participants, use this template to assess your environment:

```bash
# Workshop Environment Pattern
Hub Cluster: cluster-{hub-guid}.dynamic.redhatworkshops.io
Target Cluster: cluster-{target-guid}.dynamic.redhatworkshops.io

# Example Configuration
Hub Cluster: cluster-w66bb.dynamic.redhatworkshops.io ✅
Target Cluster: cluster-gsq4q.dynamic.redhatworkshops.io ✅
RHACM Version: 2.14.0+ ✅
OpenShift Version: 4.19+ ✅
```

### 🎯 **Typical Workshop Cluster Allocation**

Red Hat workshop environments typically provide:

1. **Hub Cluster** (`cluster-{guid1}`):
   - RHACM pre-installed
   - OpenShift GitOps ready
   - Management and orchestration role
   - **DO NOT** apply performance tuning here

2. **Target Cluster** (`cluster-{guid2}`):
   - Clean SNO cluster for performance testing
   - Where all performance tuning will be applied
   - Safe for kernel modifications and reboots
   - Managed by hub cluster via RHACM

### ⚠️ **Safety Architecture Principle**

**Never apply performance tuning to the hub cluster!**

- **Risk**: Performance tuning could disrupt RHACM management
- **Impact**: Kernel modifications might break workshop coordination
- **Solution**: Always use separate target cluster for performance testing

## Deployment Steps

### Phase 1: Hub Cluster Setup (COMPLETED)

✅ **RHACM Installation**
```bash
# Already installed and running
oc get multiclusterhub -n open-cluster-management
```

✅ **Node Tuning Operator**
```bash
# Built-in to OpenShift 4.19
oc get pods -n openshift-cluster-node-tuning-operator
```

### Phase 2: Target Cluster Import (REQUIRED)

#### Workshop Cluster Pattern Analysis

The workshop follows this standard pattern:
```bash
# Standard Workshop Pattern
Hub Cluster: cluster-{hub-guid}.dynamic.redhatworkshops.io (management)
Target Cluster: cluster-{target-guid}.dynamic.redhatworkshops.io (performance testing)

# Example from Workshop Documentation
Hub Cluster: cluster-w4hmn.w4hmn.sandbox5146.opentlc.com (management)
Target Cluster: cluster-tln8k.dynamic.redhatworkshops.io (performance testing)

# Your Workshop Environment
Hub Cluster: cluster-w66bb.dynamic.redhatworkshops.io (management) ✅
Target Cluster: cluster-gsq4q.dynamic.redhatworkshops.io (performance testing) ✅
```

#### Step-by-Step Target Cluster Import

**Prerequisites**:
- Logged into hub cluster with cluster-admin privileges
- Target cluster credentials available
- Both clusters accessible

1. **Verify Hub Cluster Connection**
   ```bash
   # Ensure you're on the hub cluster
   oc whoami
   oc get managedclusters

   # Should show local-cluster only initially
   ```

2. **Create ManagedCluster Resource**
   ```bash
   # Replace {target-guid} with your actual target cluster GUID
   export TARGET_GUID="gsq4q"  # Example: change to your target cluster GUID
   export TARGET_CLUSTER_NAME="cluster-${TARGET_GUID}"

   oc apply -f - <<EOF
   apiVersion: cluster.open-cluster-management.io/v1
   kind: ManagedCluster
   metadata:
     name: ${TARGET_CLUSTER_NAME}
     labels:
       cluster.open-cluster-management.io/clusterset: all-clusters
       environment: performance-testing
       workshop-role: target
       cloud: AWS
       vendor: OpenShift
   spec:
     hubAcceptsClient: true
   EOF
   ```

3. **Generate Import Command**
   ```bash
   # Wait for import secret to be created
   echo "Waiting for import secret..."
   oc wait --for=condition=ManagedClusterImportSucceeded=false managedcluster/${TARGET_CLUSTER_NAME} --timeout=60s

   # Extract import manifests
   oc get secret ${TARGET_CLUSTER_NAME}-import -n ${TARGET_CLUSTER_NAME} -o jsonpath='{.data.import\.yaml}' | base64 -d > ${TARGET_CLUSTER_NAME}-import.yaml

   echo "Import manifests saved to: ${TARGET_CLUSTER_NAME}-import.yaml"
   ```

4. **Apply Import Manifests on Target Cluster**
   ```bash
   # Login to target cluster (replace with your target cluster token)
   oc login --token=sha256~SCyeV48SGWCNoAUjG_CgOwbQkPMWstaFkSaC1Nz1N0c --server=https://api.cluster-${TARGET_GUID}.dynamic.redhatworkshops.io:6443

   # Apply import manifests
   oc apply -f ${TARGET_CLUSTER_NAME}-import.yaml

   # Return to hub cluster
   oc login --token=sha256~Ks-HXsluM5AhyyuSEMxDrBlG9sF31hHjfQFaxbV85Bg --server=https://api.cluster-w66bb.dynamic.redhatworkshops.io:6443
   ```

5. **Verify Import Success**
   ```bash
   # Check managed cluster status
   oc get managedclusters

   # Should show both local-cluster and your target cluster
   # Wait for target cluster to show "True" for all conditions
   oc get managedcluster ${TARGET_CLUSTER_NAME} -o yaml
   ```

#### Alternative: Workshop Environment Variables

For workshop facilitators managing multiple participants:

```bash
# Create environment-specific variables file
cat > workshop-env.sh << 'EOF'
#!/bin/bash
# Workshop Environment Configuration

# Hub Cluster (where RHACM runs)
export HUB_GUID="${HUB_GUID:-w66bb}"
export HUB_TOKEN="${HUB_TOKEN:-sha256~Ks-HXsluM5AhyyuSEMxDrBlG9sF31hHjfQFaxbV85Bg}"
export HUB_API="https://api.cluster-${HUB_GUID}.dynamic.redhatworkshops.io:6443"

# Target Cluster (where performance tuning is applied)
export TARGET_GUID="${TARGET_GUID:-gsq4q}"
export TARGET_TOKEN="${TARGET_TOKEN:-sha256~SCyeV48SGWCNoAUjG_CgOwbQkPMWstaFkSaC1Nz1N0c}"
export TARGET_API="https://api.cluster-${TARGET_GUID}.dynamic.redhatworkshops.io:6443"

# Derived values
export TARGET_CLUSTER_NAME="cluster-${TARGET_GUID}"

echo "Workshop Environment:"
echo "  Hub Cluster: ${HUB_API}"
echo "  Target Cluster: ${TARGET_API}"
echo "  Target Name: ${TARGET_CLUSTER_NAME}"
EOF

# Source the environment
source workshop-env.sh
```

#### Automated Import Script

```bash
# Create reusable import script
cat > import-target-cluster.sh << 'EOF'
#!/bin/bash
set -e

source workshop-env.sh

echo "🎯 Importing target cluster: ${TARGET_CLUSTER_NAME}"

# 1. Login to hub cluster
echo "📡 Connecting to hub cluster..."
oc login --token=${HUB_TOKEN} --server=${HUB_API}

# 2. Create ManagedCluster resource
echo "📝 Creating ManagedCluster resource..."
oc apply -f - <<YAML
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${TARGET_CLUSTER_NAME}
  labels:
    cluster.open-cluster-management.io/clusterset: all-clusters
    environment: performance-testing
    workshop-role: target
    cloud: AWS
    vendor: OpenShift
spec:
  hubAcceptsClient: true
YAML

# 3. Wait for import secret
echo "⏳ Waiting for import secret..."
timeout 120s bash -c "until oc get secret ${TARGET_CLUSTER_NAME}-import -n ${TARGET_CLUSTER_NAME} 2>/dev/null; do sleep 5; done"

# 4. Extract import manifests
echo "📦 Extracting import manifests..."
oc get secret ${TARGET_CLUSTER_NAME}-import -n ${TARGET_CLUSTER_NAME} -o jsonpath='{.data.import\.yaml}' | base64 -d > ${TARGET_CLUSTER_NAME}-import.yaml

# 5. Apply to target cluster
echo "🎯 Applying import manifests to target cluster..."
oc login --token=${TARGET_TOKEN} --server=${TARGET_API}
oc apply -f ${TARGET_CLUSTER_NAME}-import.yaml

# 6. Return to hub and verify
echo "🔍 Verifying import success..."
oc login --token=${HUB_TOKEN} --server=${HUB_API}

# Wait for cluster to be ready
timeout 300s bash -c "until oc get managedcluster ${TARGET_CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type==\"ManagedClusterConditionAvailable\")].status}' | grep -q True; do echo 'Waiting for cluster to be available...'; sleep 10; done"

echo "✅ Target cluster ${TARGET_CLUSTER_NAME} successfully imported!"
oc get managedclusters
EOF

chmod +x import-target-cluster.sh
```

#### Option C: Single Cluster Development (NOT RECOMMENDED)

For development/testing only - understand the risks:
```bash
# Label the local cluster for testing
oc label managedcluster local-cluster workshop-role=target-simulation
oc label managedcluster local-cluster environment=development-only
```

**⚠️ WARNING**: Performance tuning will affect your hub cluster!

### Phase 3: RHACM-GitOps Integration

1. **Apply Integration Resources**
   ```bash
   cd rhacm-argocd-integration
   oc apply -k .
   ```

2. **Verify Integration**
   ```bash
   # Check managed cluster set
   oc get managedclusterset all-clusters
   
   # Verify GitOps integration
   oc get gitopscluster -n openshift-gitops
   
   # Check placement decisions
   oc get placementdecision -n openshift-gitops
   ```

### Phase 4: Deploy Workshop Components

1. **Deploy to Target Cluster**
   ```bash
   # Deploy SR-IOV Network Operator
   oc apply -k gitops/sriov-network-operator/overlays/sno
   
   # Deploy OpenShift Virtualization
   oc apply -k gitops/openshift-virtualization/operator/overlays/sno
   ```

2. **Verify Deployments**
   ```bash
   # Check operators on target cluster
   oc get csv -A --context=target-cluster-context
   ```

## Validation Checklist

### Automated Validation Script

```bash
# Create comprehensive validation script
cat > validate-workshop-environment.sh << 'EOF'
#!/bin/bash
set -e

source workshop-env.sh

echo "🔍 Workshop Environment Validation"
echo "=================================="

# Hub Cluster Validation
echo "📡 Validating Hub Cluster (${HUB_API})"
oc login --token=${HUB_TOKEN} --server=${HUB_API}

echo "  ✓ Checking RHACM MultiClusterHub..."
oc get multiclusterhub -n open-cluster-management --no-headers | grep -q "Running" && echo "    ✅ RHACM Running" || echo "    ❌ RHACM Not Running"

echo "  ✓ Checking managed clusters..."
CLUSTER_COUNT=$(oc get managedclusters --no-headers | wc -l)
echo "    📊 Found ${CLUSTER_COUNT} managed clusters"
oc get managedclusters

echo "  ✓ Checking target cluster availability..."
if oc get managedcluster ${TARGET_CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' | grep -q "True"; then
    echo "    ✅ Target cluster ${TARGET_CLUSTER_NAME} is available"
else
    echo "    ❌ Target cluster ${TARGET_CLUSTER_NAME} is not available"
    exit 1
fi

# Target Cluster Validation
echo "🎯 Validating Target Cluster (${TARGET_API})"
oc login --token=${TARGET_TOKEN} --server=${TARGET_API}

echo "  ✓ Checking OpenShift version..."
OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion')
echo "    📊 OpenShift Version: ${OCP_VERSION}"

echo "  ✓ Checking Node Tuning Operator..."
oc get pods -n openshift-cluster-node-tuning-operator --no-headers | grep -q "Running" && echo "    ✅ Node Tuning Operator Running" || echo "    ❌ Node Tuning Operator Not Running"

echo "  ✓ Checking Performance Profile CRD..."
oc get crd performanceprofiles.performance.openshift.io >/dev/null 2>&1 && echo "    ✅ Performance Profile CRD Available" || echo "    ❌ Performance Profile CRD Not Available"

echo "  ✓ Checking cluster resources..."
NODE_COUNT=$(oc get nodes --no-headers | wc -l)
echo "    📊 Nodes: ${NODE_COUNT}"
oc get nodes

# Return to hub cluster
oc login --token=${HUB_TOKEN} --server=${HUB_API}

echo ""
echo "🎉 Workshop Environment Validation Complete!"
echo "Ready to proceed with GitOps deployment."
EOF

chmod +x validate-workshop-environment.sh
```

### Manual Validation Checklist

#### Hub Cluster Validation
- [ ] RHACM MultiClusterHub status: `Running`
- [ ] Managed clusters count: `2` (local-cluster + target)
- [ ] Target cluster status: `Available=True, Joined=True`
- [ ] OpenShift GitOps operator installed
- [ ] RHACM console accessible

#### Target Cluster Validation
- [ ] OpenShift version: `4.19+`
- [ ] Node Tuning Operator pods: `Running`
- [ ] Performance Profile CRD: `Available`
- [ ] Cluster resources: `Adequate for performance testing`
- [ ] Network connectivity: `Hub ↔ Target communication`

#### Integration Validation
- [ ] ManagedClusterSet: `all-clusters` configured
- [ ] Target cluster labels: `workshop-role=target`
- [ ] Import manifests: `Applied successfully`
- [ ] Klusterlet agents: `Running on target cluster`

### Quick Validation Commands

```bash
# Source environment
source workshop-env.sh

# Hub cluster quick check
oc login --token=${HUB_TOKEN} --server=${HUB_API}
oc get managedclusters
oc get multiclusterhub -n open-cluster-management

# Target cluster quick check
oc login --token=${TARGET_TOKEN} --server=${TARGET_API}
oc get nodes
oc get pods -n openshift-cluster-node-tuning-operator

# Return to hub
oc login --token=${HUB_TOKEN} --server=${HUB_API}
```

## Troubleshooting

### Common Issues

#### Target Cluster Not Available
```bash
# Check managed cluster status
oc get managedcluster target-cluster-sno -o yaml

# Check klusterlet on target
oc get pods -n open-cluster-management-agent --context=target-cluster
```

#### GitOps Integration Issues
```bash
# Check GitOpsCluster
oc get gitopscluster -n openshift-gitops -o yaml

# Verify ArgoCD cluster secrets
oc get secrets -n openshift-gitops | grep cluster
```

#### Application Sync Failures
```bash
# Check ArgoCD application status
oc get applications.argoproj.io -n openshift-gitops

# View application details
oc describe application openshift-virtualization-operator -n openshift-gitops
```

## Development Workflow

### For Workshop Developers

1. **Test on Hub Cluster First**
   ```bash
   # Validate configurations
   oc apply --dry-run=client -k gitops/base
   ```

2. **Deploy to Target via GitOps**
   ```bash
   # Let ArgoCD handle deployment
   oc patch application app-name -n openshift-gitops --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
   ```

3. **Monitor and Debug**
   ```bash
   # Watch deployment progress
   watch "oc get applications.argoproj.io -n openshift-gitops"
   ```

### For Workshop Facilitators

1. **Pre-Workshop Setup**
   - Ensure both hub and target clusters are available
   - Verify RHACM import process works
   - Test GitOps deployment pipeline
   - Validate performance testing tools

2. **Workshop Execution**
   - Participants work on hub cluster
   - Performance tuning applied to target cluster
   - Monitor both clusters during exercises

## For Workshop Facilitators: Multi-User Setup

### Participant Environment Template

Create individual environment files for each participant:

```bash
# Create participant-specific environment
create_participant_env() {
    local PARTICIPANT_NAME=$1
    local HUB_GUID=$2
    local TARGET_GUID=$3
    local HUB_TOKEN=$4
    local TARGET_TOKEN=$5

    cat > ${PARTICIPANT_NAME}-workshop-env.sh << EOF
#!/bin/bash
# Workshop Environment for ${PARTICIPANT_NAME}

export HUB_GUID="${HUB_GUID}"
export HUB_TOKEN="${HUB_TOKEN}"
export HUB_API="https://api.cluster-\${HUB_GUID}.dynamic.redhatworkshops.io:6443"

export TARGET_GUID="${TARGET_GUID}"
export TARGET_TOKEN="${TARGET_TOKEN}"
export TARGET_API="https://api.cluster-\${TARGET_GUID}.dynamic.redhatworkshops.io:6443"

export TARGET_CLUSTER_NAME="cluster-\${TARGET_GUID}"

echo "Workshop Environment for ${PARTICIPANT_NAME}:"
echo "  Hub Cluster: \${HUB_API}"
echo "  Target Cluster: \${TARGET_API}"
EOF
}

# Example usage
create_participant_env "participant1" "w66bb" "gsq4q" "sha256~Hub_Token_Here" "sha256~Target_Token_Here"
create_participant_env "participant2" "x77cc" "htr5r" "sha256~Hub_Token_Here" "sha256~Target_Token_Here"
```

### Bulk Cluster Import

```bash
# Bulk import script for multiple participants
cat > bulk-import-clusters.sh << 'EOF'
#!/bin/bash

# Array of participant configurations
declare -A PARTICIPANTS=(
    ["participant1"]="w66bb:gsq4q:hub_token:target_token"
    ["participant2"]="x77cc:htr5r:hub_token:target_token"
    # Add more participants as needed
)

for PARTICIPANT in "${!PARTICIPANTS[@]}"; do
    IFS=':' read -r HUB_GUID TARGET_GUID HUB_TOKEN TARGET_TOKEN <<< "${PARTICIPANTS[$PARTICIPANT]}"

    echo "🎯 Setting up environment for ${PARTICIPANT}"

    # Create participant environment
    create_participant_env "${PARTICIPANT}" "${HUB_GUID}" "${TARGET_GUID}" "${HUB_TOKEN}" "${TARGET_TOKEN}"

    # Import target cluster
    source ${PARTICIPANT}-workshop-env.sh
    ./import-target-cluster.sh

    echo "✅ ${PARTICIPANT} environment ready"
done
EOF
```

### Workshop Validation Dashboard

```bash
# Create validation dashboard for all participants
cat > workshop-dashboard.sh << 'EOF'
#!/bin/bash

echo "🎯 Workshop Environment Dashboard"
echo "================================"

for env_file in *-workshop-env.sh; do
    if [[ -f "$env_file" ]]; then
        PARTICIPANT=$(basename "$env_file" -workshop-env.sh)
        echo "👤 Participant: ${PARTICIPANT}"

        source "$env_file"

        # Quick health check
        if oc login --token=${HUB_TOKEN} --server=${HUB_API} >/dev/null 2>&1; then
            CLUSTER_STATUS=$(oc get managedcluster ${TARGET_CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "NotFound")
            echo "  Hub: ✅ Connected"
            echo "  Target: $([ "$CLUSTER_STATUS" = "True" ] && echo "✅ Available" || echo "❌ Not Available")"
        else
            echo "  Hub: ❌ Connection Failed"
        fi
        echo ""
    fi
done
EOF

chmod +x workshop-dashboard.sh
```

## Next Steps

### For Workshop Participants
1. **Immediate**: Source your workshop environment file
2. **Import**: Run the import script for your target cluster
3. **Validate**: Execute the validation script
4. **Setup**: Configure RHACM-GitOps integration
5. **Deploy**: Install workshop operators on target cluster
6. **Test**: Run baseline performance tests
7. **Workshop**: Begin Module 3 with proper architecture

### For Workshop Facilitators
1. **Pre-Workshop**: Create participant environment files
2. **Bulk Setup**: Run bulk import for all participants
3. **Validation**: Use dashboard to verify all environments
4. **Support**: Monitor participant progress during workshop
5. **Cleanup**: Document cleanup procedures post-workshop

## References

- [RHACM Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [Workshop Module 2](../content/modules/ROOT/pages/module-02-rhacm-setup.adoc)
