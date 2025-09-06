# RHACM-ArgoCD Integration for Multi-Cluster GitOps

This directory contains the resources needed to integrate Red Hat Advanced Cluster Management (RHACM) with ArgoCD for multi-cluster GitOps deployments.

## Overview

The integration enables:
- Centralized management of multiple OpenShift clusters through RHACM
- GitOps-based application deployment to remote clusters via ArgoCD
- Automated synchronization and healing of applications across clusters
- Declarative cluster and application management

## Architecture

```
Hub Cluster (RHACM + ArgoCD)
├── ManagedClusterSet (all-clusters)
├── ManagedClusterSetBinding (openshift-gitops namespace)
├── Placement (cluster selection rules)
├── GitOpsCluster (RHACM-ArgoCD integration)
└── ArgoCD Applications
    ├── openshift-virtualization-operator
    └── openshift-virtualization-instance
```

## Resources

### Core Integration Resources

1. **managedclusterset.yaml** - Groups managed clusters logically
2. **managedclustersetbinding.yaml** - Binds cluster set to openshift-gitops namespace
3. **placement.yaml** - Defines cluster selection criteria
4. **gitopscluster.yaml** - Integrates RHACM with ArgoCD

### Application Resources

Located in `../argocd-apps/`:
- **openshift-virtualization-operator.yaml** - Deploys CNV operator to target cluster
- **openshift-virtualization-instance.yaml** - Deploys HyperConverged instance

## Prerequisites

1. Hub cluster with RHACM installed and configured
2. Target cluster(s) imported into RHACM as managed clusters
3. OpenShift GitOps (ArgoCD) installed on hub cluster
4. Git repository with application manifests

## Quick Setup

1. Apply the integration resources:
```bash
oc apply -k .
```

2. Label managed clusters to include them in the cluster set:
```bash
oc label managedcluster <cluster-name> cluster.open-cluster-management.io/clusterset=all-clusters
```

3. Deploy applications:
```bash
oc apply -k ../argocd-apps/
```

## Verification

Check that clusters are available in ArgoCD:
```bash
oc get secrets -n openshift-gitops | grep cluster
```

Verify placement decisions:
```bash
oc get placementdecision -n openshift-gitops
```

Monitor application status:
```bash
oc get applications.argoproj.io -n openshift-gitops
```

## Troubleshooting

### Clusters not appearing in ArgoCD
- Verify ManagedClusterSetBinding is in openshift-gitops namespace
- Check that clusters have the correct clusterset label
- Ensure GitOpsCluster resource is properly configured

### Applications not syncing
- Check ArgoCD application logs
- Verify source repository accessibility
- Confirm target cluster connectivity

## Workshop Integration

This setup is designed for the Low-Latency Performance Workshop where:
- Hub cluster manages the workshop infrastructure
- Target cluster(s) run performance-sensitive workloads
- OpenShift Virtualization provides VM capabilities for testing

## Related Documentation

- [RHACM Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [Workshop Module 2](../content/modules/ROOT/pages/module-02-core-concepts.adoc)
