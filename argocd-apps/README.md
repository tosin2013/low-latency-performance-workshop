# ArgoCD Applications for Low-Latency Performance Workshop

This directory contains ArgoCD applications that deploy the operators required for the workshop on **OpenShift 4.11+**.

## Important: OpenShift 4.11+ Architecture Changes

Starting from OpenShift 4.11, the performance components architecture has changed:

- **Node Tuning Operator**: Built-in to OpenShift (no installation required)
- **Performance Addon Operator**: **DEPRECATED** - functionality moved to Node Tuning Operator
- **Performance Profiles**: Now managed directly by the Node Tuning Operator

## Applications Overview

### Performance Operators

1. **sriov-network-operator.yaml**
   - **Purpose**: High-performance networking with direct hardware access
   - **Namespace**: `openshift-sriov-network-operator`
   - **Used in**: Module 5 - Low-Latency Virtualization
   - **GitOps Path**: `gitops/sriov-network-operator/overlays/sno`
   - **Status**: Required for SR-IOV functionality

### Built-in Components (No Installation Required)
- **Node Tuning Operator**: Built-in to OpenShift 4.11+
  - **Purpose**: Manages TuneD daemon AND Performance Profiles
  - **Namespace**: `openshift-cluster-node-tuning-operator`
  - **Used in**: Module 4 (Performance Profiles) and Module 6 (TuneD profiles)
  - **Status**: Already available in all OpenShift 4.11+ clusters

### OpenShift Virtualization Components
2. **openshift-virtualization-operator.yaml**
   - **Purpose**: OpenShift Virtualization operator installation
   - **Namespace**: `openshift-cnv`
   - **Used in**: Module 5 - Low-Latency Virtualization
   - **GitOps Path**: `gitops/openshift-virtualization/operator/overlays/sno`

3. **openshift-virtualization-instance.yaml**
   - **Purpose**: OpenShift Virtualization instance configuration
   - **Namespace**: `openshift-cnv`
   - **Used in**: Module 5 - Low-Latency Virtualization
   - **GitOps Path**: `gitops/openshift-virtualization/instance`
   - **Dependencies**: Requires openshift-virtualization-operator to be ready

## Deployment Order

The applications should be deployed in this order:

1. **SR-IOV Network Operator**: Required for high-performance networking
2. **OpenShift Virtualization**:
   - OpenShift Virtualization Operator (first)
   - OpenShift Virtualization Instance (after operator is ready)

**Note**: Node Tuning Operator is already available in OpenShift 4.11+ clusters and requires no installation.

## Cluster Requirements

- **OpenShift Version**: 4.11+ (required for built-in Node Tuning Operator with Performance Profile support)
- **EC2 Instance Type**: Metal instances required for SR-IOV and performance features
- **CPU**: Dedicated cores for performance workloads
- **Memory**: Sufficient for HugePages allocation
- **Network**: SR-IOV capable network interfaces

## Applying Applications

Deploy all applications:
```bash
oc apply -k argocd-apps/
```

Monitor application status:
```bash
oc get applications -n openshift-gitops
```

Check operator deployments:
```bash
# Node Tuning Operator (built-in)
oc get tuned -n openshift-cluster-node-tuning-operator

# SR-IOV Network Operator
oc get csv -n openshift-sriov-network-operator

# OpenShift Virtualization
oc get csv -n openshift-cnv
```

## Workshop Module Integration

The operators support these workshop modules:

- **Module 2**: RHACM Setup + Operator Installation (SR-IOV only)
- **Module 4**: Performance Profiles (Node Tuning Operator - built-in)
- **Module 5**: Low-Latency Virtualization (SR-IOV + OpenShift Virtualization)
- **Module 6**: Advanced Tuning (Node Tuning Operator - built-in)

## Troubleshooting

### Common Issues

1. **SR-IOV Operator Installation Failures**
   - Ensure cluster meets hardware requirements (metal instances)
   - Verify sufficient cluster resources
   - Check ArgoCD sync status
   - Ensure metal instances with SR-IOV capable NICs
   - Check node labeling for SR-IOV nodes

2. **Performance Profile Issues** 
   - Performance Profiles are now managed by the built-in Node Tuning Operator
   - No separate operator installation required
   - Verify CPU isolation requirements
   - Check node selector configurations

3. **Missing Performance Addon Operator**
   - This operator is deprecated in OpenShift 4.11+
   - Use Performance Profiles via Node Tuning Operator instead
   - Update any existing configurations to use the new API

### Verification Commands

```bash
# Check all ArgoCD applications
argocd app list

# Sync specific application
argocd app sync sriov-network-operator

# Check built-in Node Tuning Operator
oc get tuned -n openshift-cluster-node-tuning-operator
oc get performanceprofiles

# Check SR-IOV operator health
oc get csv -n openshift-sriov-network-operator
```

## Migration from Performance Addon Operator

If migrating from older OpenShift versions (4.10 and below):

1. **Remove Performance Addon Operator** installations
2. **Migrate Performance Profiles** to Node Tuning Operator format
3. **Update ArgoCD applications** to remove deprecated operator references
4. **Test Performance Profiles** with the new Node Tuning Operator integration
