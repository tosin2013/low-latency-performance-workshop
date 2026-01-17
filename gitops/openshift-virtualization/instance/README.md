# OpenShift Virtualization Instance Configuration

This directory contains the HyperConverged CR configuration for OpenShift Virtualization.

## Structure

```
instance/
├── base/                          # Base configuration (KVM hardware virtualization)
│   ├── hyperconverged.yaml       # HyperConverged CR without emulation
│   └── kustomization.yaml
└── overlays/
    ├── sno/                       # SNO overlay (virtualized instances - uses emulation)
    │   ├── kustomization.yaml
    │   └── patch-hco-emulation.yaml  # Adds JSON patch annotation to HyperConverged
    └── standard/                  # Standard overlay (bare-metal - uses KVM)
        └── kustomization.yaml     # References base (no changes)
```

## Configuration Details

### Base Configuration
- **Purpose**: Default configuration for bare-metal instances
- **Virtualization**: Uses KVM hardware virtualization (optimal performance)
- **Use Case**: AWS `.metal` instance types, on-premises bare-metal

### SNO Overlay (Virtualized Instances)
- **Purpose**: Configuration for virtualized SNO instances (e.g., m5.4xlarge)
- **Virtualization**: Uses QEMU software emulation (TCG)
- **Use Case**: AWS virtualized EC2 instances that don't expose KVM to guests

### Standard Overlay (Bare-Metal)
- **Purpose**: Configuration for bare-metal deployments
- **Virtualization**: Uses KVM hardware virtualization (same as base)
- **Use Case**: Multi-node bare-metal clusters

## How Emulation is Configured

The HyperConverged CRD does **not** expose the `developerConfiguration.useEmulation` field directly. 
This field only exists in the KubeVirt CRD. However, KubeVirt is managed by the HyperConverged Operator (HCO),
and direct patches to KubeVirt get overwritten during HCO reconciliation.

**Solution**: Use the `kubevirt.kubevirt.io/jsonpatch` annotation on the HyperConverged CR:

```yaml
metadata:
  annotations:
    kubevirt.kubevirt.io/jsonpatch: '[{"op":"add","path":"/spec/configuration/developerConfiguration/useEmulation","value":true}]'
```

This annotation instructs HCO to apply the JSON patch to the managed KubeVirt CR, ensuring the setting persists.

## Usage

### For SNO on Virtualized Instances (m5.4xlarge)
```yaml
# ArgoCD Application
path: gitops/openshift-virtualization/instance/overlays/sno
```

### For Bare-Metal Instances
```yaml
# ArgoCD Application
path: gitops/openshift-virtualization/instance/overlays/standard
```

## Performance Considerations

| Configuration | VM Boot Time | CPU Performance | Use Case |
|--------------|--------------|-----------------|----------|
| **KVM (Base/Standard)** | 30-60 seconds | Native speed | Production, bare-metal |
| **Emulation (SNO)** | 2-5 minutes | 10-50x slower | Educational, virtualized instances |

## Verification

To verify emulation is enabled after deployment:

```bash
# Check the annotation on HyperConverged
oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.metadata.annotations.kubevirt\.kubevirt\.io/jsonpatch}'

# Check the KubeVirt CR has the setting applied
oc get kubevirt kubevirt-kubevirt-hyperconverged -n openshift-cnv -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
# Should return: true
```
