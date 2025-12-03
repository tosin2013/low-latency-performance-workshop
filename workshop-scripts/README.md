# Workshop Scripts

Automation scripts for deploying the Low-Latency Performance Workshop using AgnosticD with ansible-navigator.

## Script Overview

### Initial Setup (Run Once)

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `01-setup-ansible-navigator.sh` | Install and configure ansible-navigator | Once per bastion |
| `02-configure-aws-credentials.sh` | Setup AWS credentials and pull secret | Once per bastion |

### SNO Deployment

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `03-test-single-sno.sh` | Test deploy single student SNO | Before full deployment |
| `04-provision-student-clusters.sh` | Deploy all student SNOs (batch mode) | Large-scale deployment |

### Multi-User Workshop Setup (NEW)

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `05-setup-hub-users.sh` | Create htpasswd users and install Dev Spaces | After hub cluster ready |
| `06-provision-user-snos.sh` | Deploy SNO clusters in parallel | After users created |
| `07-setup-user-devspaces.sh` | Update Dev Spaces secrets with SNO credentials | After SNO deployment |
| `08-provision-complete-workshop.sh` | **Master script** - runs all setup steps | Complete workshop setup |
| `09-setup-module02-rhacm.sh` | Automate Module-02 RHACM-ArgoCD setup | Before users start module |

### Cleanup

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `99-destroy-all-students.sh` | Destroy all student clusters | Post-workshop |
| `99-destroy-sno.sh` | Destroy single SNO cluster | As needed |

## Quick Start - Multi-User Workshop

### Complete Workshop Setup (Recommended)

```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# 1. Initial setup (if not done)
./01-setup-ansible-navigator.sh
./02-configure-aws-credentials.sh

# 2. Login to hub cluster
oc login https://api.cluster-xxx.dynamic.redhatworkshops.io:6443

# 3. Run complete workshop setup for 5 users
./08-provision-complete-workshop.sh 5

# This will:
#   - Create htpasswd users (student1-student5)
#   - Install OpenShift Dev Spaces
#   - Deploy 5 SNO clusters (parallel)
#   - Configure Dev Spaces with SNO credentials
#   - Setup RHACM-ArgoCD integration
```

### Step-by-Step Setup

```bash
# 1. Setup hub cluster (users + Dev Spaces)
./05-setup-hub-users.sh 5

# 2. Deploy SNO clusters (parallel)
./06-provision-user-snos.sh 5 3  # 5 users, 3 parallel

# 3. Update Dev Spaces secrets
./07-setup-user-devspaces.sh 5

# 4. Setup Module-02 RHACM
./09-setup-module02-rhacm.sh
```

### Single User Testing

```bash
# Test with single user first
./03-test-single-sno.sh student1 rhpds

# Verify
oc get managedcluster workshop-student1
```

## User Experience

After setup, each user gets:

1. **Login credentials**: `studentN` / `workshop`
2. **Dev Spaces workspace** with:
   - Kubeconfig auto-mounted at `/home/user/.kube/config`
   - SSH key auto-mounted at `/home/user/.ssh/id_rsa`
   - Workshop repository cloned
3. **SNO cluster**: `workshop-studentN`
4. **Personalized documentation** (optional)

### User Workflow

1. Login to OpenShift console
2. Open Dev Spaces dashboard
3. Start "low-latency-workshop" workspace
4. Run `oc get nodes` to verify SNO access
5. Follow workshop modules

## Prerequisites

- RHPDS "ACM for Kubernetes Demo" or similar hub cluster
- SSH access to hub bastion
- AWS credentials (access key + secret)
- OpenShift pull secret from console.redhat.com
- AgnosticD repository cloned (`~/agnosticd`)

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HUB_API_URL` | Hub cluster API endpoint |
| `HUB_KUBECONFIG` | Path to hub kubeconfig |
| `SUBDOMAIN_BASE_SUFFIX` | Cluster subdomain suffix |

### Files Created

| File | Purpose |
|------|---------|
| `~/.ansible-navigator.yaml` | ansible-navigator config |
| `~/.aws/credentials` | AWS credentials |
| `~/pull-secret.json` | OpenShift pull secret |
| `~/secrets-ec2.yml` | AgnosticD secrets |
| `~/agnosticd-output/` | SNO kubeconfigs and SSH keys |

## AgnosticD Configurations

### Hub Cluster Setup

The `agnosticd-configs/low-latency-workshop-hub/` config provides:

- HTPasswd authentication workload
- Dev Spaces installation workload
- Per-user namespace creation
- Dev Spaces secret mounting

### SNO Deployment

The `agnosticd-configs/low-latency-workshop-sno/` config provides:

- Single Node OpenShift deployment
- RHACM auto-import
- Bastion host setup

## Troubleshooting

### Dev Spaces secrets not mounting

```bash
# Check secrets have correct labels
oc get secrets -n workshop-student1 -l controller.devfile.io/mount-to-devworkspace=true

# Check secret annotations
oc get secret student1-kubeconfig -n workshop-student1 -o yaml
```

### SNO not accessible from Dev Spaces

```bash
# Verify kubeconfig secret content
oc get secret student1-kubeconfig -n workshop-student1 -o jsonpath='{.data.config}' | base64 -d

# Re-run secret update
./07-setup-user-devspaces.sh 5
```

### RHACM import failed

```bash
# Check managed cluster status
oc get managedcluster workshop-student1 -o yaml

# Manual import script is generated
cat /tmp/manual-import-workshop-student1.sh
```

### ArgoCD apps not syncing

```bash
# Check application status
oc get applications.argoproj.io -n openshift-gitops

# Check app details
oc describe application openshift-virtualization-operator -n openshift-gitops
```

## Logs

| Log Location | Content |
|--------------|---------|
| `/tmp/workshop-provision-*/` | Complete workshop provisioning logs |
| `/tmp/sno-provision-*/` | SNO deployment logs |
| `/tmp/test-studentN.log` | Single SNO test logs |
| `~/ansible-artifacts/` | ansible-navigator artifacts |

## Support

For detailed documentation:

- Deployment guide: `docs/deployment/README.md`
- User quick start: `docs/USER_QUICK_START.md`
- AgnosticD hub config: `agnosticd-configs/low-latency-workshop-hub/README.adoc`
