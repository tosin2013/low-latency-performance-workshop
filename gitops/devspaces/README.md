# OpenShift Dev Spaces GitOps Configuration

This directory contains GitOps resources for deploying OpenShift Dev Spaces.

## Structure

```
devspaces/
├── operator/                 # Dev Spaces Operator installation
│   ├── namespace.yaml       # openshift-devspaces namespace
│   ├── operatorgroup.yaml   # OperatorGroup
│   ├── subscription.yaml    # Operator subscription
│   └── kustomization.yaml
├── instance/                 # CheCluster instance
│   ├── checluster.yaml      # Dev Spaces configuration
│   └── kustomization.yaml
├── kustomization.yaml        # Top-level kustomization
└── README.md
```

## Deployment

### Deploy Everything

```bash
oc apply -k gitops/devspaces/
```

### Deploy Operator Only

```bash
oc apply -k gitops/devspaces/operator/
```

### Deploy Instance Only (after operator is ready)

```bash
oc apply -k gitops/devspaces/instance/
```

## Configuration

The CheCluster is configured for the workshop with:

- **Max 1 running workspace per user**
- **4Gi memory limit** for workspaces
- **Auto-provisioning** of user namespaces
- **VS Code-based IDE** (che-code)
- **1800 seconds** idle timeout

## Secret Mounting

Dev Spaces automatically mounts secrets with specific labels into workspaces.

To create a secret that auto-mounts:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: <user-namespace>
  labels:
    controller.devfile.io/mount-to-devworkspace: "true"
    controller.devfile.io/watch-secret: "true"
  annotations:
    controller.devfile.io/mount-path: /home/user/.kube
    controller.devfile.io/mount-as: subpath
data:
  config: <base64-encoded-content>
type: Opaque
```

## Verification

```bash
# Check operator
oc get csv -n openshift-devspaces

# Check CheCluster
oc get checluster -n openshift-devspaces

# Get Dev Spaces URL
oc get checluster devspaces -n openshift-devspaces -o jsonpath='{.status.cheURL}'
```

## Integration with Workshop

The `05-setup-hub-users.sh` script:
1. Installs Dev Spaces operator
2. Creates CheCluster instance
3. Creates per-user namespaces
4. Creates labeled secrets for auto-mounting kubeconfig and SSH keys

Users can then start workspaces that have their SNO cluster credentials automatically available.

