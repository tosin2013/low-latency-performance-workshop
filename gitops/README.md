# GitOps Configuration for Low Latency Performance Workshop

This directory contains the GitOps configuration for deploying workshop applications using the existing OpenShift GitOps ArgoCD instance, which already has proper security contexts and permissions.

## Overview

The configuration uses the App-of-Apps pattern to deploy workshop content:

```
gitops/
├── base/                           # Workshop ArgoCD Applications
│   ├── kustomization.yaml         # Base kustomization
│   ├── workshop-project.yaml      # ArgoCD Project for workshop
│   └── workshop-app-of-apps.yaml  # App-of-Apps pattern
├── applications/                   # Individual workshop applications
│   ├── kustomization.yaml
│   ├── operators/                  # Operator installations
│   ├── performance-profiles/       # Performance tuning configs
│   └── sample-workloads/          # Workshop workloads
└── overlays/                      # Environment-specific configurations
    ├── aws/                       # AWS-specific settings
    └── baremetal/                 # Bare-metal specific settings
```

## Security Features

The ArgoCD configuration includes comprehensive OpenShift security contexts:

### Security Contexts Applied
- **runAsNonRoot**: `true` for all components
- **readOnlyRootFilesystem**: `true` for all containers
- **allowPrivilegeEscalation**: `false` for all containers
- **seccompProfile**: `RuntimeDefault` for enhanced security
- **capabilities**: All capabilities dropped (`drop: [ALL]`)

### Components Secured
- ArgoCD Server
- ArgoCD Application Controller
- ArgoCD Repository Server
- Redis
- ApplicationSet Controller
- Dex (OpenShift OAuth integration)

### RBAC Configuration
- Dedicated service accounts for each component
- Cluster roles with minimal required permissions
- Support for OpenShift-specific resources (Routes, SCCs, etc.)
- Integration with OpenShift OAuth for authentication

## Deployment

### Prerequisites
- OpenShift cluster access with cluster-admin privileges
- `oc` CLI tool installed and configured
- `kustomize` CLI tool installed

### Quick Deployment

1. **For AWS environment:**
   ```bash
   ./scripts/deploy-argocd.sh aws
   ```

2. **For bare-metal environment:**
   ```bash
   ./scripts/deploy-argocd.sh baremetal
   ```

### Manual Deployment

1. **Install OpenShift GitOps Operator:**
   ```bash
   kustomize build gitops/base | oc apply -f -
   ```

2. **Deploy ArgoCD for specific environment:**
   ```bash
   # For AWS
   kustomize build gitops/overlays/aws | oc apply -f -
   
   # For bare-metal
   kustomize build gitops/overlays/baremetal | oc apply -f -
   ```

### Validation

Run the security validation script:
```bash
./scripts/validate-argocd-security.sh
```

## Environment Differences

### AWS Configuration
- Higher resource limits for better performance
- Optimized for cloud networking
- Enhanced route annotations for load balancing
- JSON logging format for better cloud integration

### Bare-metal Configuration
- Conservative resource limits
- Optimized for on-premises networking
- Extended timeouts for slower storage
- Text logging format for easier debugging

## Access Information

After deployment, ArgoCD will be available via OpenShift Route:

1. **Get the URL:**
   ```bash
   oc get route workshop-argocd-server -n openshift-gitops -o jsonpath='{.spec.host}'
   ```

2. **Get admin password:**
   ```bash
   oc get secret workshop-argocd-initial-admin-secret -n openshift-gitops -o jsonpath='{.data.password}' | base64 -d
   ```

3. **Login:**
   - Username: `admin`
   - Password: (from step 2)

## Integration with OpenShift

### OAuth Integration
ArgoCD is configured to use OpenShift OAuth for authentication:
- Users can login with their OpenShift credentials
- RBAC policies map OpenShift groups to ArgoCD roles
- Cluster administrators automatically get admin access

### Route Configuration
- TLS termination: `reencrypt` for end-to-end encryption
- Automatic certificate management via OpenShift
- Load balancing and high availability

### Security Context Constraints (SCCs)
The configuration uses appropriate SCCs:
- `anyuid` for components that need specific user IDs
- `privileged` only when absolutely necessary
- Minimal privilege principle applied throughout

## Troubleshooting

### Common Issues

1. **Operator not installing:**
   - Check OperatorHub connectivity
   - Verify cluster-admin permissions
   - Check for existing installations

2. **ArgoCD not starting:**
   - Check resource quotas in openshift-gitops namespace
   - Verify security context constraints
   - Check pod logs: `oc logs -n openshift-gitops -l app.kubernetes.io/name=workshop-argocd`

3. **Route not accessible:**
   - Verify route exists: `oc get route -n openshift-gitops`
   - Check TLS configuration
   - Verify DNS resolution

### Debugging Commands

```bash
# Check operator status
oc get csv -n openshift-gitops-operator

# Check ArgoCD instance
oc get argocd workshop-argocd -n openshift-gitops -o yaml

# Check all pods
oc get pods -n openshift-gitops

# Check logs
oc logs -n openshift-gitops -l app.kubernetes.io/part-of=workshop-argocd
```

## Repository Configuration

The ArgoCD instance is pre-configured with the workshop repository:
- Repository URL: `https://github.com/tosin2013/low-latency-performance-workshop.git`
- Projects configured for both AWS and bare-metal environments
- Automatic sync policies can be enabled as needed

## Next Steps

After successful deployment:

1. Configure additional repositories as needed
2. Create ArgoCD Applications for workshop components
3. Set up monitoring and alerting
4. Configure backup and disaster recovery
5. Implement GitOps workflows for workshop content

## References

- [ADR-004: Install OpenShift GitOps Operator](../docs/adrs/004-install-openshift-gitops-operator.md)
- [ADR-001: Use GitOps for Workshop Deployment](../docs/adrs/001-use-gitops-for-workshop-deployment.md)
- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
