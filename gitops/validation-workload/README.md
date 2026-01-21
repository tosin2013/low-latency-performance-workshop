# SNO Development Cluster Validation

This directory contains Kubernetes manifests for validating SNO development clusters after deployment.

**Note:** These manifests are standalone and do **not** require ArgoCD. They can be applied directly with `oc apply` or `kubectl apply`. While located in the `gitops/` directory for organization, they are not managed by GitOps and can be used independently.

## Overview

The validation workload performs comprehensive checks to ensure all workshop features are working correctly:

1. **OpenShift Virtualization Operator**
   - Verifies HyperConverged (HCO) CR exists and is available
   - Checks KubeVirt CR exists
   - Verifies virt-handler pods are running

2. **KVM Emulation Configuration**
   - For virtualized instances (m5.4xlarge): Verifies emulation is enabled
   - For bare-metal instances (m5zn.metal): Skips check (not needed)
   - Checks both KubeVirt CR and ConfigMap (legacy method)

3. **Test VM Creation**
   - Creates a minimal Cirros test VM
   - Starts the VM and waits for it to boot
   - Verifies VM reaches Running state
   - Cleans up test VM after validation

4. **Cert Manager Operator**
   - Verifies operator pods are running

5. **Node Health**
   - Checks SNO node is in Ready state

## Files

- **`validation-job.yaml`**: Kubernetes Job that runs all validation checks
  - Includes ServiceAccount, Role, and RoleBinding for RBAC
  - ConfigMap containing test VM manifest
  - Job runs validation script and writes results to ConfigMap

- **`test-vm.yaml`**: Standalone test VM manifest (can be used independently)
  - Minimal Cirros VM (512Mi RAM, 1 CPU)
  - Uses container disk (no PVC required)
  - Suitable for quick validation tests

## Requirements

- **OpenShift/Kubernetes cluster** with OpenShift Virtualization installed
- **oc** or **kubectl** CLI tool
- **No ArgoCD required** - these are standalone manifests

## Usage

### Automated (via deploy script)

```bash
./scripts/deploy-sno-dev.sh dev1 sandbox3576 virtualized
```

The deploy script automatically applies the validation job and waits for results.

### Manual

```bash
# Apply validation job
oc apply -f gitops/validation-workload/validation-job.yaml

# Wait for completion (check job status)
oc get job sno-validation -n default

# View job logs
oc logs job/sno-validation -n default

# Check results
oc get configmap sno-validation-results -n default -o yaml
```

### Using Validation Script

```bash
export KUBECONFIG=~/Development/agnosticd-v2-output/dev1/openshift-cluster_dev1_kubeconfig
./scripts/validate-sno-dev.sh dev1 virtualized
```

## Validation Results

Results are stored in a ConfigMap (`sno-validation-results`) with the following structure:

```yaml
data:
  passed: "5"
  warnings: "1"
  failed: "0"
  instance_type: "m5.4xlarge"
  is_metal: "false"
  timestamp: "2024-01-15T10:30:00Z"
  results: |
    PASS|OpenShift Virtualization Operator|HCO is available
    PASS|KubeVirt CR|KubeVirt CR exists
    PASS|virt-handler Pods|1 pod(s) running
    PASS|KVM Emulation|Emulation enabled for virtualized instance
    PASS|Test VM Created|VM manifest applied successfully
    ...
```

## Test VM

The test VM is a minimal Cirros instance that:
- Boots quickly (container disk, no image pull needed)
- Uses minimal resources (512Mi RAM, 1 CPU)
- Runs a simple keepalive script
- Is automatically cleaned up after validation

To use the test VM independently:

```bash
# Create test VM
oc apply -f gitops/validation-workload/test-vm.yaml

# Start VM
oc patch virtualmachine validation-test-vm -n default --type merge -p '{"spec":{"running":true}}'

# Check status
oc get vmi validation-test-vm -n default

# Delete VM
oc delete virtualmachine validation-test-vm -n default
```

## Troubleshooting

### Validation Job Fails

1. Check job logs:
   ```bash
   oc logs job/sno-validation -n default
   ```

2. Check job status:
   ```bash
   oc describe job sno-validation -n default
   ```

3. Check pod status:
   ```bash
   oc get pods -n default -l app=sno-validation
   ```

### Test VM Doesn't Boot

1. Check VMI status:
   ```bash
   oc get vmi validation-test-vm -n default
   oc describe vmi validation-test-vm -n default
   ```

2. Check virt-handler logs:
   ```bash
   oc logs -n openshift-cnv -l kubevirt.io=virt-handler --tail=100
   ```

3. Verify emulation is enabled (for virtualized instances):
   ```bash
   oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o yaml | grep useEmulation
   ```

### Emulation Check Fails

For virtualized instances (m5.4xlarge), emulation must be enabled. Check:

1. KubeVirt CR:
   ```bash
   oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
   ```

2. ConfigMap (legacy method):
   ```bash
   oc get configmap -n openshift-cnv kubevirt-config -o jsonpath='{.data.debug\.useEmulation}'
   ```

If emulation is not enabled, apply the SNO overlay:
```bash
# Ensure GitOps is configured to use sno overlay for virtualized instances
# See: gitops/openshift-virtualization/instance/overlays/virtualized/
```
