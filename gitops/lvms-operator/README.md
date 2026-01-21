# LVM Storage Operator (LVMS) for Bare-Metal Deployments

> ⚠️ **EXPERIMENTAL**: This LVMS integration for boot source images is still being tested on bare-metal deployments. The current recommendation is to use `gp3-csi` (EBS) for boot source golden images, and LVMS for VM runtime workloads where low-latency storage is needed. **Contributions and testing feedback are welcome!**

This directory contains GitOps configuration for deploying the LVM Storage operator on bare-metal SNO clusters to provide fast local storage for OpenShift Virtualization VMs.

## Current Status

| Use Case | Recommended Storage | Status |
|----------|---------------------|--------|
| Boot source images (golden images) | `gp3-csi` | ✅ Stable - uses EBS snapshots |
| VM runtime disks | `lvms-vg-local` | 🧪 Testing - lower latency |
| Low-latency workloads | `lvms-vg-local` | 🧪 Testing - best I/O performance |

### Known Issues

1. **Volume Populator compatibility**: CDI Volume Populators have issues with LVMS `WaitForFirstConsumer` binding mode for golden images
2. **Slow qemu-img conversion**: Boot source imports use qemu-img QCOW2→RAW conversion which is CPU-intensive (~45 min for 6 images)
3. **Concurrent import limits**: 6 parallel imports compete for CPU (750m limit per pod) and thin pool I/O

### Contributing

We welcome contributions to improve LVMS integration! Areas that need work:
- [ ] Volume Populator compatibility testing
- [ ] Optimizing CDI resource limits for LVMS
- [ ] Testing with different instance types
- [ ] Documentation improvements

Please open issues or PRs at: https://github.com/tosin2013/low-latency-performance-workshop

## Overview

The LVM Storage operator manages local block storage using LVM (Logical Volume Manager), providing:
- **Faster VM provisioning**: Eliminates EBS snapshot wait times (2-5 minutes → seconds)
- **Better I/O performance**: Local block storage has lower latency than network-attached EBS
- **Thin provisioning**: Efficient storage utilization with overprovisioning

## Architecture

```
┌─────────────────────────────────────┐
│  Bare-Metal SNO Instance (m5zn.metal)│
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Root Disk (EBS gp3)          │  │
│  │ - OpenShift OS               │  │
│  │ - Control plane data         │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ LVM Disk (EBS gp3)           │  │
│  │ - Managed by LVMS operator   │  │
│  │ - StorageClass: lvms-vg-local│  │
│  │ - Used for VM root disks     │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Directory Structure

```
lvms-operator/
├── operator/                    # Operator installation
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── operator-group.yaml
│   │   ├── subscription.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       └── baremetal/
│           └── kustomization.yaml
└── instance/                    # LVMCluster CR
    ├── base/
    │   ├── lvmcluster.yaml
    │   └── kustomization.yaml
    └── overlays/
        └── baremetal/
            └── kustomization.yaml
```

## Prerequisites

1. **Additional EBS Volume**: The bare-metal instance must have an extra EBS volume attached
   - Size: 500GB (configurable)
   - Type: gp3
   - Device path: `/dev/nvme1n1` (or `/dev/xvdf` depending on instance type)

2. **AgnosticD Configuration**: The deployment config must include the extra volume
   - See `agnosticd-v2-vars/low-latency-sno-dev.yml` for configuration

## Deployment

### Manual Deployment

```bash
# 1. Install LVMS operator
oc apply -k gitops/lvms-operator/operator/overlays/baremetal

# 2. Wait for operator to be ready
oc wait --for=condition=Available deployment/lvms-operator -n openshift-storage --timeout=300s

# 3. Create LVMCluster
oc apply -k gitops/lvms-operator/instance/overlays/baremetal

# 4. Wait for LVMCluster to be ready
oc wait --for=condition=Ready lvmcluster/lvms-cluster -n openshift-storage --timeout=600s
```

### GitOps Deployment (ArgoCD)

Add to your ArgoCD applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lvms-operator
  namespace: openshift-gitops
spec:
  source:
    repoURL: https://github.com/tosin2013/low-latency-performance-workshop.git
    targetRevision: HEAD
    path: gitops/lvms-operator/operator/overlays/baremetal
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-storage
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lvms-instance
  namespace: openshift-gitops
spec:
  source:
    repoURL: https://github.com/tosin2013/low-latency-performance-workshop.git
    targetRevision: HEAD
    path: gitops/lvms-operator/instance/overlays/baremetal
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-storage
```

## Verification

```bash
# Check operator status
oc get pods -n openshift-storage

# Check LVMCluster status
oc get lvmcluster -n openshift-storage
oc describe lvmcluster lvms-cluster -n openshift-storage

# Check StorageClass
oc get storageclass lvms-vg-local

# Check volume group
oc get lvmvolumegroup -n openshift-storage
```

## Storage Class Configuration

The LVMS operator creates a StorageClass `lvms-vg-local` that can be used for VM workloads:

```yaml
# Set as default for virtualization workloads
oc annotate storageclass lvms-vg-local \
  storageclass.kubevirt.io/is-default-virt-class=true
```

## Device Path Notes

AWS EC2 instance types use different device naming:
- **NVMe instances** (m5zn.metal, c5.metal, etc.): `/dev/nvme1n1`, `/dev/nvme2n1`, etc.
- **Xen instances** (older types): `/dev/xvdf`, `/dev/xvdg`, etc.
- **SCSI instances**: `/dev/sdf`, `/dev/sdg`, etc.

The LVMCluster configuration includes multiple possible paths. Verify the actual device path after deployment:

```bash
# SSH to node and check
lsblk
# or
oc debug node/<node-name> -- lsblk
```

Then update the LVMCluster if needed.

## Troubleshooting

### LVMCluster Not Ready

```bash
# Check events
oc get events -n openshift-storage --sort-by='.lastTimestamp'

# Check operator logs
oc logs -n openshift-storage deployment/lvms-operator

# Check device availability
oc debug node/<node-name> -- lsblk
```

### Device Not Found

If the device path is incorrect:
1. Identify the correct device path on the node
2. Update `lvmcluster.yaml` with the correct path
3. Delete and recreate the LVMCluster

### Storage Class Not Created

Ensure the LVMCluster is in `Ready` state. The StorageClass is created automatically when the cluster is ready.

## Performance Comparison

| Storage Type | VM Provisioning Time | I/O Latency | Use Case |
|--------------|---------------------|-------------|----------|
| **EBS gp3 (snapshot clone)** | 2-5 minutes | ~1-2ms | Standard workloads |
| **LVM Local (LVMS)** | 10-30 seconds | ~0.1-0.5ms | Low-latency VMs |

## References

- [Red Hat LVM Storage Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/storage/configuring-persistent-storage/persistent-storage-local)
- [LVMS Operator GitHub](https://github.com/openshift/lvm-operator)
