# Low-Latency Performance Workshop

A hands-on workshop for understanding and optimizing low-latency workloads on OpenShift using:
- Single Node OpenShift (SNO)
- OpenShift Virtualization
- RHACM (Red Hat Advanced Cluster Management)
- ArgoCD/GitOps
- Performance tuning and real-time kernel configurations

## Quick Start for Administrators

### Deployment Options

| Scenario | Command | Time | Purpose |
|----------|---------|------|---------|
| [AgnosticD v2 (Recommended)](#agnosticd-v2-deployment) | `./scripts/workshop-setup.sh` | ~5 min setup | Modern, simplified deployment |
| [Single User (v1/RHPDS)](#single-user-deployment-testing) | `make provision-single` | ~45 min | End-to-end testing with hub |
| [Multi-User (v1/RHPDS)](#multi-user-deployment-workshop) | `make provision USERS=5` | ~2 hrs | Full workshop with hub |

---

## AgnosticD v2 Deployment (Recommended)

**New simplified deployment using AgnosticD V2 - no hub cluster required!**

### Quick Setup

```bash
# Run automated setup (checks prerequisites, clones repos, configures environment)
cd ~/Development/low-latency-performance-workshop
./scripts/workshop-setup.sh
```

### Configure Secrets

1. **Edit `~/Development/agnosticd-v2-secrets/secrets.yml`**:
   - Add OpenShift pull secret from console.redhat.com
   - Configure Satellite or RHN repositories (for bastion packages)

2. **Create `~/Development/agnosticd-v2-secrets/secrets-sandboxXXX.yml`**:
   - Add AWS credentials from demo.redhat.com
   - Replace XXX with your sandbox number

3. **Edit `agnosticd-v2-vars/low-latency-sno-aws.yml`**:
   - Update `cloud_tags.owner` with your email
   - Add `host_ssh_authorized_keys` with your GitHub username

### Deploy SNO Cluster

```bash
# Deploy single SNO cluster
./scripts/deploy-sno.sh student1 sandbox1234

# Check status
./scripts/status-sno.sh student1 sandbox1234

# Destroy cluster
./scripts/destroy-sno.sh student1 sandbox1234
```

### What Gets Deployed

- **SNO Cluster**: Single Node OpenShift 4.20 on AWS
- **Bastion**: t3a.medium instance for cluster management
- **Workloads**: Cert Manager, OpenShift Virtualization, Showroom (workshop docs)

### Access Information

After deployment, check:
- **Kubeconfig**: `~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig`
- **Password**: `~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeadmin-password`
- **User Info**: `~/Development/agnosticd-v2-output/student1/provision-user-info.yaml`

For detailed setup instructions, see [docs/WORKSHOP_SETUP.md](docs/WORKSHOP_SETUP.md).

---

## Single User Deployment (Testing)

**Use this to validate the entire workshop flow end-to-end with `user1`.**

### Prerequisites

```bash
# SSH to RHPDS bastion
ssh lab-user@bastion.{your-guid}.dynamic.opentlc.com

# Navigate to workshop root
cd /home/lab-user/low-latency-performance-workshop

# Check available commands
make help
```

### One-Time Setup

```bash
# Run prerequisites setup (ansible-navigator, verify AgnosticD)
./workshop-scripts/setup-prerequisites.sh

# Configure AWS credentials (interactive prompts)
./workshop-scripts/helpers/02-configure-aws-credentials.sh
```

### Deploy for user1

```bash
# Login to hub cluster (get URL from RHPDS email)
oc login https://api.cluster-xxx.dynamic.redhatworkshops.io:6443

# Deploy single user (user1) - this is all you need!
make provision-single
```

That's it! The `make provision-single` command will:
1. Setup hub cluster users and namespaces
2. Deploy SNO cluster for user1 on AWS
3. Configure Dev Spaces secrets
4. Deploy personalized documentation
5. Install operators (OpenShift Virtualization, SR-IOV)

### Verify Single User Deployment

```bash
# Check managed cluster
oc get managedclusters workshop-user1

# Check docs deployment
oc get build,deployment,route -n workshop-user1

# Check Dev Spaces secrets
oc get secret -n workshop-user1 -l controller.devfile.io/mount-to-devworkspace=true
```

### Test User Experience

1. **Login to OpenShift console**: `user1` / `<workshop-password>`
2. **Open Dev Spaces**: Click "Red Hat OpenShift Dev Spaces" in application launcher
3. **Create workspace**: Use URL `https://github.com/tosin2013/low-latency-performance-workshop`
4. **Verify SNO access**: Run `oc get nodes` in Dev Spaces terminal
5. **Access docs**: Open `https://docs-user1.apps.{domain}`

---

## Multi-User Deployment (Workshop)

### Quick Deploy

```bash
# Deploy for 5 users (default)
make provision USERS=5

# Deploy for 10 users
make provision USERS=10

# Deploy users 6-10 only (incremental)
make provision USERS=10 START_USER=6

# Use custom prefix (student1, student2, etc.)
make provision USERS=5 USER_PREFIX=student
```

### Monitor Progress

```bash
# Watch managed clusters
watch -n 30 'oc get managedclusters'

# Check deployment logs
ls /tmp/workshop-provision-*/
tail -f /tmp/workshop-provision-*/user1-deployment.log
```

---

## Expected Output (RHPDS Deployment)

After successful deployment, each user will have:

### Per-User Resources

| Resource | Description |
|----------|-------------|
| SNO Cluster | Single Node OpenShift on AWS (workshop-userX) |
| Hub Namespace | `workshop-userX` namespace on hub cluster |
| Dev Spaces Namespace | `userX-devspaces` for IDE workspace |
| ManagedCluster | RHACM-managed cluster entry |
| Workshop User | `userX` with cluster-admin on their SNO |
| Personalized Docs | `https://docs-userX.apps.<hub-domain>` |

### Output Files (per user)

```
~/agnosticd-output/workshop-userX/
├── kubeconfig                              # SNO cluster access
├── ssh_provision_workshop-userX            # SSH private key
├── ssh_provision_workshop-userX.pub        # SSH public key
├── low-latency-workshop-sno_..._kubeadmin-password
├── deployment-summary.txt                  # Deployment details
└── provision-user-info.yaml                # User connection info
```

### Installed Operators (on each SNO)

- OpenShift Virtualization
- SR-IOV Network Operator
- Node Tuning Operator (built-in)

### Estimated Deployment Time

| Scenario | Time |
|----------|------|
| Single user | ~45-90 minutes |
| 5 users (sequential) | ~5 hours |
| 10 users (sequential) | ~10 hours |

---

## Instance Size Requirements

### Current Configuration

| Component | Instance | vCPU | RAM | Notes |
|-----------|----------|------|-----|-------|
| Bastion | t3a.medium | 2 | 4 GB | Runs openshift-install |
| SNO | m5.4xlarge | 16 | 64 GB | All-in-one OpenShift |

### OpenShift Virtualization Requirements

> **Note**: For full OpenShift Virtualization workloads, consider larger instances.

**Recommended for VM workloads:**

| Instance | vCPU | RAM | Nested Virt | Notes |
|----------|------|-----|-------------|-------|
| `m5.metal` | 96 | 384 GB | Full | Best for VMs |
| `m5.8xlarge` | 32 | 128 GB | Nested | Lower cost option |
| `m5.4xlarge` | 16 | 64 GB | Nested | Testing only |

**To change instance type**, edit:
```yaml
# AgnosticD v2 (recommended)
# agnosticd-v2-vars/low-latency-sno-aws.yml
control_plane_instance_type: m5.metal  # or m5.8xlarge for testing

# AgnosticD v1 (legacy)
# agnosticd-configs/low-latency-workshop-sno/default_vars_ec2.yml
sno_instance_type: m5.metal  # or m5.8xlarge for testing
```

### Cost Considerations

| Instance | Hourly (us-east-2) | Per SNO/Day | 5 Users/Day |
|----------|-------------------|-------------|-------------|
| m5.4xlarge | ~$0.77 | ~$18.50 | ~$92 |
| m5.8xlarge | ~$1.54 | ~$37 | ~$185 |
| m5.metal | ~$4.61 | ~$110 | ~$550 |

---

## User Access Information

After deployment, share with users:

```
═══════════════════════════════════════════════════════════════
  LOW-LATENCY PERFORMANCE WORKSHOP
═══════════════════════════════════════════════════════════════

  OpenShift Console: https://console-openshift-console.apps.{hub-domain}
  
  Username: userN  (user1, user2, ...)
  Password: <provided by administrator>
  
  Dev Spaces: https://devspaces.apps.{hub-domain}
  (Use "Create Workspace" with this repo URL)
  
  Your Documentation: https://docs-userN.apps.{hub-domain}
  
═══════════════════════════════════════════════════════════════
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HUB CLUSTER (RHPDS)                           │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────────────────┐ │
│  │   RHACM     │  │   Dev Spaces     │  │   Per-User Namespaces      │ │
│  │             │  │                  │  │   workshop-user1           │ │
│  │  Manages    │  │  IDE workspace   │  │   ├── BuildConfig (docs)   │ │
│  │  all SNO    │  │  per user        │  │   ├── ImageStream          │ │
│  │  clusters   │  │  Auto-mounts:    │  │   ├── Deployment (httpd)   │ │
│  │             │  │  - kubeconfig    │  │   ├── Route (docs-user1)   │ │
│  │             │  │  - SSH key       │  │   ├── kubeconfig Secret    │ │
│  │             │  │  - SNO info      │  │   └── SSH key Secret       │ │
│  └─────────────┘  └──────────────────┘  └────────────────────────────┘ │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │ SNO user1   │      │ SNO user2   │      │ SNO userN   │
   │ (AWS EC2)   │      │ (AWS EC2)   │      │ (AWS EC2)   │
   │             │      │             │      │             │
   │ Workloads:  │      │ Workloads:  │      │ Workloads:  │
   │ - CNV       │      │ - CNV       │      │ - CNV       │
   │ - kube-burner│     │ - kube-burner│     │ - kube-burner│
   └─────────────┘      └─────────────┘      └─────────────┘
```

---

## Directory Structure

```
low-latency-performance-workshop/
├── Makefile                     # Main entry point for v1/RHPDS deployment
├── README.adoc                  # Project overview
├── devfile.yaml                 # Dev Spaces workspace definition
├── agnosticd-v2-vars/            # AgnosticD v2 configurations (NEW)
│   ├── low-latency-sno-aws.yml      # SNO cluster config
│   └── README.md                    # Config documentation
├── scripts/                      # AgnosticD v2 deployment scripts (NEW)
│   ├── workshop-setup.sh            # Full automated setup
│   ├── deploy-sno.sh                # Deploy SNO cluster
│   ├── destroy-sno.sh                # Destroy SNO cluster
│   └── status-sno.sh                 # Check cluster status
├── agnosticd-configs/            # AgnosticD v1 configurations (LEGACY)
│   ├── low-latency-workshop-hub/    # Hub cluster setup (v1)
│   └── low-latency-workshop-sno/    # SNO cluster deployment (v1)
├── content/                     # Antora workshop content
│   └── modules/ROOT/pages/          # Module documentation
├── gitops/                      # GitOps resources
│   ├── devspaces/                   # Dev Spaces operator + instance
│   ├── workshop-docs/               # BuildConfig for docs
│   └── ...
└── workshop-scripts/            # v1/RHPDS deployment automation
    ├── provision-workshop.sh        # Main provisioning script (v1)
    ├── destroy-workshop.sh          # Cleanup script (v1)
    ├── setup-prerequisites.sh       # One-time setup
    ├── README.md                    # Detailed script documentation
    └── helpers/                     # Helper scripts
        ├── 00-install-rhacm.sh
        ├── 01-setup-ansible-navigator.sh
        ├── 02-configure-aws-credentials.sh
        ├── 05-setup-hub-users.sh
        └── ...                      # (deprecated v1 scripts removed - use scripts/deploy-sno.sh for v2)
```

---

## Cleanup

### Single User

```bash
# Destroy user1 resources
make destroy USERS=1
```

### Multi-User

```bash
# Destroy all users (default 5)
make destroy

# Destroy 10 users
make destroy USERS=10
```

### Advanced Cleanup (Stuck VPCs)

```bash
# List all VPCs
make list-vpcs

# Force delete a specific VPC and all its resources
make cleanup-vpc VPC_ID=vpc-xxxxxxxxx
```

---

## Troubleshooting

### Check SNO Status

```bash
# Via RHACM
oc get managedcluster workshop-user1

# Direct access (if kubeconfig available)
oc --kubeconfig=~/agnosticd-output/workshop-user1/kubeconfig get nodes
```

### View Deployment Logs

```bash
# Find log directory
ls -la /tmp/workshop-provision-*/

# View specific user log
cat /tmp/workshop-provision-*/user1-deployment.log
```

### Common Issues

| Issue | Solution |
|-------|----------|
| SNO not joining RHACM | Check AWS security groups, verify auto-import secret |
| Build failing | Check BuildConfig logs: `oc logs bc/workshop-docs -n workshop-userX` |
| Dev Spaces not mounting secrets | Verify labels: `controller.devfile.io/mount-to-devworkspace=true` |

---

## Additional Documentation

- **AgnosticD v2 Setup**: [docs/WORKSHOP_SETUP.md](docs/WORKSHOP_SETUP.md) - Complete setup guide for v2
- **Detailed script docs (v1)**: [workshop-scripts/README.md](workshop-scripts/README.md)
- **Project overview**: [README.adoc](README.adoc)
- **AgnosticD v2 reference**: [agnosticd/agnosticd-v2](https://github.com/agnosticd/agnosticd-v2)
- **AgnosticD v1 reference**: [RedHatGov/agnosticd](https://github.com/redhat-cop/agnosticd)

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes with actual workshop environment
4. Submit PR with signed commits (`git commit -s`)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/tosin2013/low-latency-performance-workshop/issues)
- **Docs**: See `workshop-scripts/README.md` for detailed deployment docs
