# Workshop Scripts

Scripts for deploying and managing the Low-Latency Performance Workshop.

## Quick Start (Using Makefile)

```bash
# From the project root directory:
cd /home/lab-user/low-latency-performance-workshop

# Deploy workshop for 5 users (user1-user5)
make provision USERS=5

# Deploy single user for testing
make provision-single

# Destroy all resources
make destroy
```

## Provisioning Process Overview

The workshop deployment has **7 sequential steps per user**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT FLOW (per user)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Deploy SNO Cluster                                      │
│    └─→ Creates CloudFormation stack in AWS                       │
│    └─→ Provisions bastion + SNO node                             │
│    └─→ Output: ~/agnosticd-output/workshop-userX/                │
│                                                                  │
│  Step 2: Wait for SNO Ready (90 min timeout)                     │
│    └─→ Monitors RHACM ManagedCluster status                      │
│    └─→ Waits for JOINED=True, AVAILABLE=True                     │
│                                                                  │
│  Step 3: RHACM Import                                            │
│    └─→ Creates ManagedCluster resource                           │
│    └─→ Applies auto-import secret                                │
│                                                                  │
│  Step 4: Deploy Operators to SNO                                 │
│    └─→ OpenShift Virtualization                                  │
│    └─→ SR-IOV Network Operator                                   │
│    └─→ Node Tuning Operator (built-in)                          │
│                                                                  │
│  Step 5: Setup Dev Spaces Secrets    ◄── NEW STEP                │
│    └─→ Creates kubeconfig secret for auto-mount                  │
│    └─→ Creates SSH key secret for auto-mount                     │
│    └─→ Creates SNO info ConfigMap                                │
│                                                                  │
│  Step 6: Deploy Workshop Documentation                           │
│    └─→ BuildConfig, Deployment, Service, Route                   │
│    └─→ URL: https://docs-userX.<cluster-domain>                  │
│                                                                  │
│  Step 7: Verify Deployment                                       │
│    └─→ Checks kubeconfig exists                                  │
│    └─→ Verifies ManagedCluster status                           │
│                                                                  │
│  ═══════════════════════════════════════════════════════════════ │
│  ✓ userX complete! Move to next user...                          │
└─────────────────────────────────────────────────────────────────┘
```

**Key Point**: Deployments are **sequential** - each user's entire setup completes before the next user starts. This avoids CloudFormation conflicts.

## Main Scripts

| Script | Purpose |
|--------|---------|
| `provision-workshop.sh` | **MAIN** - Deploy complete workshop for N users (sequential) |
| `destroy-workshop.sh` | Clean up all workshop resources |
| `cleanup-vpc.sh` | Advanced: Delete all resources in a specific VPC |
| `setup-prerequisites.sh` | One-time setup: Ansible Navigator, AWS credentials |

## Makefile Targets

```bash
# From project root:

# === Provisioning ===
make provision                      # Deploy user1-user5 (default)
make provision USERS=10             # Deploy user1-user10
make provision USERS=10 START_USER=6  # Deploy user6-user10 only
make provision-single               # Deploy user1 only (for testing)
make provision USER_PREFIX=student  # Use 'student' prefix

# === Destruction ===
make destroy                        # Destroy all resources (interactive)
make destroy USERS=10               # Destroy 10 users

# === Advanced Cleanup ===
make list-vpcs                      # List all VPCs in AWS
make cleanup-vpc VPC_ID=vpc-xxx     # Delete specific VPC and all resources
make cleanup-vpc-force VPC_ID=vpc-xxx  # Force delete (no confirmation)
```

## Helper Scripts (can be run individually)

| Script | Purpose | Usage |
|--------|---------|-------|
| `helpers/deploy-single-sno.sh` | Deploy single SNO cluster | `./helpers/deploy-single-sno.sh user1 rhpds` |
| `helpers/07-setup-user-devspaces.sh` | Setup Dev Spaces secrets | `./helpers/07-setup-user-devspaces.sh 1 user 1` |
| `helpers/deploy-workshop-docs.sh` | Deploy documentation | `./helpers/deploy-workshop-docs.sh 1 user` |
| `helpers/check-sno-status.sh` | Check SNO health | `./helpers/check-sno-status.sh user1` |
| `helpers/05-setup-hub-users.sh` | Create hub users | `./helpers/05-setup-hub-users.sh 5` |

### 07-setup-user-devspaces.sh

Creates secrets for Dev Spaces auto-mounting:

```bash
# Single user
./helpers/07-setup-user-devspaces.sh 1 user 1    # Just user1

# Multiple users
./helpers/07-setup-user-devspaces.sh 5 user 1    # user1-user5
./helpers/07-setup-user-devspaces.sh 10 user 6   # user6-user10
```

**What it creates:**
- `userX-kubeconfig` secret → mounted at `/home/user/.kube/config`
- `userX-ssh-key` secret → mounted at `/home/user/.ssh/id_rsa`
- `userX-sno-info` ConfigMap → SNO connection info

### deploy-workshop-docs.sh

Deploys personalized documentation for users:

```bash
./helpers/deploy-workshop-docs.sh 1 user    # Docs for user1
./helpers/deploy-workshop-docs.sh 5 user    # Docs for user1-user5
```

**What it creates:**
- BuildConfig (builds docs from source)
- Deployment
- Service
- Route (https://docs-userX.<cluster-domain>)

## Prerequisites

Before running provisioning:

1. **Logged into Hub Cluster**
   ```bash
   oc login <hub-api-url> -u admin
   oc whoami  # Verify
   ```

2. **RHACM Installed** on hub cluster
   ```bash
   oc get csv -n open-cluster-management | grep advanced-cluster-management
   ```

3. **AWS Credentials** configured
   ```bash
   cat ~/secrets-ec2.yml  # Should have aws_access_key_id, aws_secret_access_key
   ```

4. **AgnosticD** cloned
   ```bash
   ls ~/agnosticd  # Should exist
   ```

5. **Pull Secret** available
   ```bash
   cat ~/pull-secret.json  # OpenShift pull secret
   ```

## Output Files

After provisioning, you'll find:

| Location | Contents |
|----------|----------|
| `~/agnosticd-output/workshop-userX/` | Kubeconfig, SSH keys, passwords |
| `workshop-credentials.txt` | All user credentials summary |
| `/tmp/workshop-provision-*/` | Deployment logs |

### Per-user output files:
```
~/agnosticd-output/workshop-user1/
├── kubeconfig                    # SNO kubeconfig
├── ssh_provision_workshop-user1  # SSH private key
├── ssh_provision_workshop-user1.pub
├── low-latency-workshop-sno_workshop-user1_kubeadmin-password
├── deployment-summary.txt
└── ...
```

## Namespaces Created

For each user, these namespaces are created on the **hub cluster**:

| Namespace | Purpose |
|-----------|---------|
| `workshop-userX` | User's main workshop namespace |
| `userX-devspaces` | Dev Spaces workspace namespace |

## Troubleshooting

### Check SNO Status
```bash
# Via RHACM
oc get managedcluster workshop-user1

# Direct access
oc --kubeconfig=~/agnosticd-output/workshop-user1/kubeconfig get nodes
```

### Test Bastion SSH
```bash
ssh -i ~/agnosticd-output/workshop-user1/ssh_provision_workshop-user1 \
    ec2-user@<bastion-ip>
```

### View Deployment Logs
```bash
# Find latest log directory
ls -la /tmp/workshop-provision-*

# View user-specific log
cat /tmp/workshop-provision-*/user1-deployment.log
```

### Check Dev Spaces Secrets
```bash
# List secrets with auto-mount label
oc get secrets -n workshop-user1 -l controller.devfile.io/mount-to-devworkspace=true

# Check ConfigMap
oc get configmap user1-sno-info -n workshop-user1 -o yaml
```

### Re-run Individual Steps
```bash
# Re-deploy SNO (if failed)
./helpers/deploy-single-sno.sh user1 rhpds

# Re-setup Dev Spaces secrets
./helpers/07-setup-user-devspaces.sh 1 user 1

# Re-deploy docs
./helpers/deploy-workshop-docs.sh 1 user
```

### Force Cleanup a VPC
```bash
# Find VPC ID
make list-vpcs

# Delete everything in that VPC
make cleanup-vpc VPC_ID=vpc-0123456789abcdef
```

## Estimated Times

| Operation | Time |
|-----------|------|
| Single SNO deployment | ~30-45 minutes |
| Wait for SNO ready | Up to 90 minutes (usually faster) |
| Operators installation | ~10 minutes |
| Dev Spaces secrets | ~1 minute |
| Documentation deployment | ~2 minutes |
| **Total per user** | **~45-90 minutes** |

For multiple users (sequential): `N users × ~60 minutes`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        HUB CLUSTER                               │
│  (your-hub-cluster.<subdomain>)                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ RHACM        │  │ Dev Spaces   │  │ htpasswd     │           │
│  │ (manages     │  │ (IDE for     │  │ (user1,      │           │
│  │  SNO clusters)│  │  users)      │  │  user2...)   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                 │                                      │
│         │    ┌────────────┴────────────┐                        │
│         │    │     Namespaces          │                        │
│         │    │  ┌─────────────────┐    │                        │
│         │    │  │ workshop-user1  │    │                        │
│         │    │  │ - kubeconfig    │    │                        │
│         │    │  │ - ssh-key       │    │                        │
│         │    │  │ - sno-info      │    │                        │
│         │    │  │ - docs route    │    │                        │
│         │    │  └─────────────────┘    │                        │
│         │    └─────────────────────────┘                        │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ManagedClusters                              │   │
│  │  workshop-user1, workshop-user2, ...                      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │
         │ (manages via RHACM)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AWS (us-east-2)                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ workshop-user1  │  │ workshop-user2  │  │ workshop-userN  │  │
│  │ (SNO Cluster)   │  │ (SNO Cluster)   │  │ (SNO Cluster)   │  │
│  │                 │  │                 │  │                 │  │
│  │ • Bastion       │  │ • Bastion       │  │ • Bastion       │  │
│  │ • SNO Node      │  │ • SNO Node      │  │ • SNO Node      │  │
│  │ • Operators:    │  │ • Operators:    │  │ • Operators:    │  │
│  │   - Virt        │  │   - Virt        │  │   - Virt        │  │
│  │   - SR-IOV      │  │   - SR-IOV      │  │   - SR-IOV      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
