# SR-IOV Network Operator GitOps Configuration

This directory contains GitOps manifests for deploying the SR-IOV Network Operator for high-performance networking.

## Purpose

The SR-IOV Network Operator:
- Manages Single-Root I/O Virtualization for direct hardware access
- Enables high-performance networking with minimal latency
- Provides SR-IOV network device plugins
- Required for Module 5 (Low-Latency Virtualization)

## Structure

```
sriov-network-operator/
├── base/
│   ├── kustomization.yaml    # Base resources
│   ├── namespace.yaml        # Operator namespace
│   ├── operator-group.yaml   # Operator group
│   └── subscription.yaml     # Operator subscription
└── overlays/
    └── sno/
        ├── kustomization.yaml # SNO-specific overlay
        └── patch-sno.yaml    # SNO-specific patches
```

## SNO-Specific Configuration

The SNO overlay includes:
- Disabled node drain during SR-IOV configuration
- Annotation to prevent single-node disruption

## Deployment

This operator is deployed automatically via ArgoCD as part of Module 2 setup.

## Key Features

- **Direct Hardware Access**: Bypasses kernel networking stack
- **Low Latency**: Reduces network latency for performance-critical workloads
- **Virtual Functions**: Creates SR-IOV virtual functions for VM networking
- **Device Management**: Automated SR-IOV device configuration

## Notes

- Requires SR-IOV capable network hardware
- SNO-specific patches prevent node drain
- SR-IOV configuration will be covered in Module 5
