# Workshop Deployment Guide - Multi-Cluster Setup

## Overview

This guide provides step-by-step instructions for properly deploying the Low-Latency Performance Workshop using a simplified two-cluster architecture.

## Architecture Requirements

The workshop uses a **two-cluster architecture** for safety and best practices:

### Hub Cluster (Documentation)
- **Purpose**: Hosts workshop documentation (Showroom) for all students
- **Components**: OpenShift GitOps, Showroom, Cert Manager
- **Role**: Provides stable documentation access during student cluster operations
- **Safety**: No performance tuning applied here

### SNO Cluster (Performance Testing)
- **Purpose**: Performance tuning, workload testing, kernel modifications
- **Components**: Node Tuning Operator, SR-IOV, OpenShift Virtualization
- **Role**: Standalone cluster for hands-on performance tuning exercises
- **Safety**: Isolated environment for potentially disruptive changes

## Prerequisites

### Hub Cluster Requirements
- OpenShift 4.19+ cluster with cluster-admin access
- Minimum 8 vCPU, 16GB RAM for Showroom hosting
- Internet connectivity for operator installations

### SNO Cluster Requirements  
- Single Node OpenShift (SNO) 4.19+ recommended
- Bare metal or VM with performance capabilities
- Minimum 8 vCPU, 16GB RAM, 100GB storage
- Suitable for kernel modifications and reboots

## Environment Assessment Template

For workshop facilitators and participants, use this template to assess your environment:

```bash
# Workshop Environment Pattern
Hub Cluster: cluster-{hub-guid}.dynamic.redhatworkshops.io
SNO Cluster: cluster-{sno-guid}.dynamic.redhatworkshops.io

# Example Configuration
Hub Cluster: cluster-w66bb.dynamic.redhatworkshops.io ✅
SNO Cluster: cluster-gsq4q.dynamic.redhatworkshops.io ✅
OpenShift Version: 4.19+ ✅
```

### 🎯 **Typical Workshop Cluster Allocation**

Red Hat workshop environments typically provide:

1. **Hub Cluster** (`cluster-{guid1}`):
   - OpenShift GitOps ready
   - Hosts Showroom documentation
   - **DO NOT** apply performance tuning here

2. **SNO Cluster** (`cluster-{guid2}`):
   - Clean SNO cluster for performance testing
   - Where all performance tuning will be applied
   - Safe for kernel modifications and reboots
   - Standalone (not managed by hub)

### ⚠️ **Safety Architecture Principle**

**Never apply performance tuning to the hub cluster!**

- **Risk**: Performance tuning could disrupt Showroom availability
- **Impact**: Kernel modifications might break documentation access
- **Solution**: Always use separate SNO cluster for performance testing

## Deployment Steps

### Phase 1: Deploy SNO Clusters (FIRST)

Deploy student SNO clusters first to generate bastion credentials needed for the Hub cluster.

#### Using AgnosticD v2

```bash
cd ~/Development/agnosticd-v2

# Deploy SNO cluster for a student
./bin/agd provision \
  --guid student1 \
  --config low-latency-sno-aws \
  --account sandbox28ptm
```

#### Collect Bastion Credentials

After each SNO deployment, collect the bastion credentials:

```bash
# Credentials are stored in:
~/Development/agnosticd-v2-output/{guid}/openshift-cluster_{guid}_bastion_ssh_key
```

**Important**: Save these credentials - they're needed for Hub cluster Showroom configuration.

### Phase 2: Deploy Hub Cluster (SECOND)

Deploy the Hub cluster with collected student credentials for Showroom configuration.

#### Using AgnosticD v2

```bash
cd ~/Development/agnosticd-v2

# Deploy Hub cluster
./bin/agd provision \
  --guid hub-cluster \
  --config workshop-hub-aws \
  --account sandbox28ptm
```

#### Configure Showroom for Students

After Hub deployment, configure Showroom instances for each student:

```bash
cd ~/low-latency-performance-workshop
./scripts/deploy-student-showrooms.sh --students student1,student2
```

Each student will get their own Showroom URL:
- Student1: `https://student1-workshop-low-latency-workshop.apps.ocp.hub.sandbox5466.opentlc.com/`
- Student2: `https://student2-workshop-low-latency-workshop.apps.ocp.hub.sandbox5466.opentlc.com/`

### Phase 3: Deploy Workshop Components on SNO

Deploy operators and workloads on the SNO cluster for performance testing.

#### Using GitOps (Recommended)

```bash
# Deploy SR-IOV Network Operator
oc apply -k gitops/sriov-network-operator/overlays/sno

# Deploy OpenShift Virtualization
oc apply -k gitops/openshift-virtualization/operator/overlays/sno
```

#### Manual Deployment

```bash
# Or deploy directly to SNO cluster
oc login --token=<sno-token> --server=https://api.cluster-<sno-guid>.dynamic.redhatworkshops.io:6443

# Apply operators
oc apply -k gitops/sriov-network-operator/overlays/sno
oc apply -k gitops/openshift-virtualization/operator/overlays/sno
```

## Validation Checklist

### Automated Validation Script

```bash
# Create comprehensive validation script
cat > validate-workshop-environment.sh << 'EOF'
#!/bin/bash
set -e

echo "🔍 Workshop Environment Validation"
echo "=================================="

# Hub Cluster Validation
echo "📡 Validating Hub Cluster"
if oc login --token=${HUB_TOKEN} --server=${HUB_API} >/dev/null 2>&1; then
    echo "  ✅ Hub cluster accessible"
    
    echo "  ✓ Checking OpenShift GitOps..."
    oc get pods -n openshift-gitops --no-headers | grep -q "Running" && echo "    ✅ OpenShift GitOps Running" || echo "    ❌ OpenShift GitOps Not Running"
    
    echo "  ✓ Checking Showroom..."
    oc get pods -n low-latency-workshop --no-headers | grep -q "Running" && echo "    ✅ Showroom Running" || echo "    ❌ Showroom Not Running"
else
    echo "  ❌ Hub cluster not accessible"
fi

# SNO Cluster Validation
echo "🎯 Validating SNO Cluster"
if oc login --token=${SNO_TOKEN} --server=${SNO_API} >/dev/null 2>&1; then
    echo "  ✅ SNO cluster accessible"
    
    echo "  ✓ Checking OpenShift version..."
    OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion')
    echo "    📊 OpenShift Version: ${OCP_VERSION}"
    
    echo "  ✓ Checking Node Tuning Operator..."
    oc get pods -n openshift-cluster-node-tuning-operator --no-headers | grep -q "Running" && echo "    ✅ Node Tuning Operator Running" || echo "    ❌ Node Tuning Operator Not Running"
    
    echo "  ✓ Checking Performance Profile CRD..."
    oc get crd performanceprofiles.performance.openshift.io >/dev/null 2>&1 && echo "    ✅ Performance Profile CRD Available" || echo "    ❌ Performance Profile CRD Not Available"
    
    echo "  ✓ Checking SR-IOV Network Operator..."
    oc get csv -n openshift-sriov-network-operator --no-headers | grep -q "Succeeded" && echo "    ✅ SR-IOV Operator Installed" || echo "    ❌ SR-IOV Operator Not Installed"
    
    echo "  ✓ Checking OpenShift Virtualization..."
    oc get csv -n openshift-cnv --no-headers | grep -q "Succeeded" && echo "    ✅ OpenShift Virtualization Installed" || echo "    ❌ OpenShift Virtualization Not Installed"
    
    echo "  ✓ Checking cluster resources..."
    NODE_COUNT=$(oc get nodes --no-headers | wc -l)
    echo "    📊 Nodes: ${NODE_COUNT}"
    oc get nodes
else
    echo "  ❌ SNO cluster not accessible"
fi

echo ""
echo "🎉 Workshop Environment Validation Complete!"
EOF

chmod +x validate-workshop-environment.sh
```

### Manual Validation Checklist

#### Hub Cluster Validation
- [ ] OpenShift GitOps operator installed and running
- [ ] Showroom pods running in `low-latency-workshop` namespace
- [ ] Showroom routes accessible
- [ ] Cert Manager installed (for SSL certificates)

#### SNO Cluster Validation
- [ ] OpenShift version: `4.19+`
- [ ] Node Tuning Operator pods: `Running`
- [ ] Performance Profile CRD: `Available`
- [ ] SR-IOV Network Operator: `Installed`
- [ ] OpenShift Virtualization: `Installed`
- [ ] Cluster resources: `Adequate for performance testing`

### Quick Validation Commands

```bash
# Hub cluster quick check
oc login --token=${HUB_TOKEN} --server=${HUB_API}
oc get pods -n openshift-gitops
oc get pods -n low-latency-workshop

# SNO cluster quick check
oc login --token=${SNO_TOKEN} --server=${SNO_API}
oc get nodes
oc get pods -n openshift-cluster-node-tuning-operator
oc get csv -A
```

## Troubleshooting

### Common Issues

#### Showroom Not Accessible
```bash
# Check Showroom pods
oc get pods -n low-latency-workshop

# Check routes
oc get routes -n low-latency-workshop

# Check logs
oc logs -n low-latency-workshop -l app=workshop-docs
```

#### SNO Cluster Operators Not Installing
```bash
# Check operator subscriptions
oc get subscriptions -A

# Check operator CSV status
oc get csv -A

# Check operator logs
oc logs -n openshift-sriov-network-operator -l name=sriov-network-operator
```

#### Performance Profile Not Working
```bash
# Check Node Tuning Operator
oc get pods -n openshift-cluster-node-tuning-operator

# Check Performance Profile
oc get performanceprofile

# Check Tuned daemon
oc get tuned -A
```

## Development Workflow

### For Workshop Developers

1. **Test Configurations**
   ```bash
   # Validate configurations
   oc apply --dry-run=client -k gitops/base
   ```

2. **Deploy to SNO via GitOps**
   ```bash
   # Apply to SNO cluster
   oc login --token=${SNO_TOKEN} --server=${SNO_API}
   oc apply -k gitops/sriov-network-operator/overlays/sno
   ```

3. **Monitor and Debug**
   ```bash
   # Watch deployment progress
   watch "oc get csv -A"
   ```

### For Workshop Facilitators

1. **Pre-Workshop Setup**
   - Deploy SNO clusters for all participants
   - Collect bastion credentials
   - Deploy Hub cluster with Showroom
   - Configure per-student Showroom instances
   - Validate all clusters are accessible

2. **Workshop Execution**
   - Participants access Showroom on Hub cluster
   - Performance tuning applied to individual SNO clusters
   - Monitor both clusters during exercises

## For Workshop Facilitators: Multi-User Setup

### Participant Environment Template

Create individual environment files for each participant:

```bash
# Create participant-specific environment
create_participant_env() {
    local PARTICIPANT_NAME=$1
    local HUB_GUID=$2
    local SNO_GUID=$3
    local HUB_TOKEN=$4
    local SNO_TOKEN=$5

    cat > ${PARTICIPANT_NAME}-workshop-env.sh << EOF
#!/bin/bash
# Workshop Environment for ${PARTICIPANT_NAME}

export HUB_GUID="${HUB_GUID}"
export HUB_TOKEN="${HUB_TOKEN}"
export HUB_API="https://api.cluster-\${HUB_GUID}.dynamic.redhatworkshops.io:6443"

export SNO_GUID="${SNO_GUID}"
export SNO_TOKEN="${SNO_TOKEN}"
export SNO_API="https://api.cluster-\${SNO_GUID}.dynamic.redhatworkshops.io:6443"

echo "Workshop Environment for ${PARTICIPANT_NAME}:"
echo "  Hub Cluster: \${HUB_API}"
echo "  SNO Cluster: \${SNO_API}"
EOF
}

# Example usage
create_participant_env "participant1" "w66bb" "gsq4q" "sha256~Hub_Token_Here" "sha256~SNO_Token_Here"
create_participant_env "participant2" "x77cc" "htr5r" "sha256~Hub_Token_Here" "sha256~SNO_Token_Here"
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
            echo "  Hub: ✅ Connected"
        else
            echo "  Hub: ❌ Connection Failed"
        fi
        
        if oc login --token=${SNO_TOKEN} --server=${SNO_API} >/dev/null 2>&1; then
            echo "  SNO: ✅ Connected"
        else
            echo "  SNO: ❌ Connection Failed"
        fi
        echo ""
    fi
done
EOF

chmod +x workshop-dashboard.sh
```

## Next Steps

### For Workshop Participants
1. **Access**: Open your Showroom URL from the Hub cluster
2. **Connect**: Access your SNO cluster via bastion or oc login
3. **Validate**: Run validation script to verify environment
4. **Deploy**: Install workshop operators on SNO cluster
5. **Test**: Run baseline performance tests
6. **Workshop**: Begin Module 3 with proper architecture

### For Workshop Facilitators
1. **Pre-Workshop**: Deploy SNO clusters for all participants
2. **Collect**: Gather bastion credentials from SNO deployments
3. **Deploy**: Deploy Hub cluster with Showroom
4. **Configure**: Set up per-student Showroom instances
5. **Validate**: Use dashboard to verify all environments
6. **Support**: Monitor participant progress during workshop

## References

- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [AgnosticD v2 Documentation](https://github.com/redhat-cop/agnosticd)
- [Workshop Module 2](../content/modules/ROOT/pages/module-02-rhacm-setup.adoc)
