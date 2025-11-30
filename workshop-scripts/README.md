# Workshop Scripts

Automation scripts for deploying the Low-Latency Performance Workshop using AgnosticD with ansible-navigator.

## Script Overview

Execute scripts in this order:

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `01-setup-ansible-navigator.sh` | Install and configure ansible-navigator | Once per bastion |
| `02-configure-aws-credentials.sh` | Setup AWS credentials and pull secret | Once per bastion |
| `03-test-single-sno.sh` | Test deploy single student SNO (supports RHPDS/standalone modes) | Before full deployment |
| `04-provision-student-clusters.sh` | Deploy all student SNOs (RHPDS mode) | Workshop setup |
| `05-verify-workshop-ready.sh` | Verify all clusters ready | Post-deployment |
| `99-cleanup-workshop.sh` | Destroy all student clusters | Post-workshop |

## Quick Start

### For RHPDS Workshop (with Hub Integration)

```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# 1. Setup ansible-navigator
./01-setup-ansible-navigator.sh

# 2. Configure credentials
./02-configure-aws-credentials.sh

# 3. Login to hub cluster
oc login https://api.cluster-xxx.dynamic.redhatworkshops.io:6443

# 4. Test with single SNO (RHPDS mode)
./03-test-single-sno.sh student1

# 5. Verify test worked
oc get managedcluster workshop-student1

# 6. Deploy for all students
./04-provision-student-clusters.sh 30

# 7. Verify readiness
./05-verify-workshop-ready.sh
```

### For Standalone Deployment (No Hub)

```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# 1. Setup ansible-navigator
./01-setup-ansible-navigator.sh

# 2. Configure credentials
./02-configure-aws-credentials.sh

# 3. Test with single SNO (standalone mode)
./03-test-single-sno.sh student1 standalone

# 4. Access SNO directly
oc --kubeconfig ~/agnosticd-output/test-student1/kubeconfig get nodes
```

## Prerequisites

- RHPDS "ACM for Kubernetes Demo (CNV Pools)" provisioned
- SSH access to hub bastion
- AWS credentials (access key + secret)
- OpenShift pull secret from console.redhat.com

## Environment Variables

These scripts use/set:

- `HUB_API_URL` - Hub cluster API endpoint
- `HUB_KUBECONFIG` - Path to hub kubeconfig
- `PATH` - Updated to include ~/.local/bin

## Configuration Files Created

Scripts create these files if they don't exist:

- `~/.ansible-navigator.yaml` - ansible-navigator configuration
- `~/.aws/credentials` - AWS credentials
- `~/pull-secret.json` - OpenShift pull secret
- `~/secrets-ec2.yml` - AgnosticD secrets file

## Logs

Deployment logs are saved to:

- `/tmp/provision-student{N}.log` - Per-student deployment logs
- `~/ansible-artifacts/` - ansible-navigator artifacts
- `~/agnosticd-output/` - AgnosticD output files

## Troubleshooting

### Script fails with "command not found"

```bash
# Ensure scripts are executable
chmod +x *.sh

# Check PATH
echo $PATH | grep local/bin
```

### AWS credentials not working

```bash
# Verify credentials
aws sts get-caller-identity

# Re-run credential setup
./02-configure-aws-credentials.sh
```

### SNO fails to import to RHACM

```bash
# Check hub RHACM status
oc get multiclusterhub -n open-cluster-management

# Verify ManagedClusterSet exists
oc get managedclusterset workshop-clusters
```

## Support

For detailed deployment documentation, see `docs/deployment/README.md`

