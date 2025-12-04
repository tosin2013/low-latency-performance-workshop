# Low-Latency Performance Workshop

A hands-on workshop for understanding and optimizing low-latency workloads on OpenShift using:
- Single Node OpenShift (SNO)
- OpenShift Virtualization
- RHACM (Red Hat Advanced Cluster Management)
- ArgoCD/GitOps
- Performance tuning and real-time kernel configurations

## 🚀 Quick Start for Administrators

### Deployment Options

| Scenario | Users | Time | Purpose |
|----------|-------|------|---------|
| [Single User](#single-user-deployment-testing) | 1 | ~45 min | End-to-end testing |
| [Multi-User](#multi-user-deployment-workshop) | 5-20 | ~2 hrs | Full workshop |

---

## Single User Deployment (Testing)

**Use this to validate the entire workshop flow end-to-end with `user1`.**

### Prerequisites

```bash
# SSH to RHPDS bastion
ssh lab-user@bastion.{your-guid}.dynamic.opentlc.com

# Navigate to workshop
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# 1. Setup ansible-navigator (one-time)
./01-setup-ansible-navigator.sh

# 2. Configure AWS credentials
./02-configure-aws-credentials.sh --help  # Shows required info
./02-configure-aws-credentials.sh
```

### Deploy for user1

```bash
# 3. Login to hub cluster (get URL from RHPDS email)
oc login https://api.cluster-xxx.dynamic.redhatworkshops.io:6443

# 4. Install RHACM operator (if not present)
./00-install-rhacm.sh

# 5. Setup hub cluster for 1 user
./05-setup-hub-users.sh 1 user

# 6. Deploy SNO cluster for user1
./03-test-single-sno.sh user1 rhpds

# 7. Update Dev Spaces with SNO credentials
./07-setup-user-devspaces.sh 1 user
```

### Verify Single User Deployment

```bash
# Check managed cluster
oc get managedclusters workshop-user1

# Check docs deployment (BuildConfig/ImageStream)
oc get build,imagestream,deployment -n workshop-user1

# Check docs URL
oc get route -n workshop-user1

# Check Dev Spaces secrets
oc get secret -n workshop-user1 -l controller.devfile.io/mount-to-devworkspace=true
```

### Test User Experience

1. **Login to OpenShift console**: `user1` / `workshop`
2. **Open Dev Spaces**: Click "Red Hat OpenShift Dev Spaces" in application launcher
3. **Create workspace**: Use URL `https://github.com/tosin2013/low-latency-performance-workshop`
4. **Verify SNO access**: Run `oc get nodes` in Dev Spaces terminal
5. **Access docs**: Open `https://docs-user1.apps.{domain}`

---

## Multi-User Deployment (Workshop)

> ⚠️ **Status: Currently Testing** - Multi-user parallel deployment is functional but undergoing validation.

### One-Command Deployment

```bash
# Deploy for 5 users (default)
./08-provision-complete-workshop.sh 5

# Or with custom prefix
./08-provision-complete-workshop.sh 10 user
```

### Step-by-Step Deployment

```bash
# 1. Install RHACM
./00-install-rhacm.sh

# 2. Setup hub (users + Dev Spaces)
./05-setup-hub-users.sh 5 user

# 3. Deploy SNO clusters (parallel)
./06-provision-user-snos.sh 5 3 user  # 5 users, 3 parallel

# 4. Update Dev Spaces secrets
./07-setup-user-devspaces.sh 5 user

# 5. Setup Module-02 RHACM-ArgoCD (optional pre-setup)
./09-setup-module02-rhacm.sh
```

### Monitor Progress

```bash
# Watch managed clusters
watch -n 30 'oc get managedclusters'

# Watch builds (docs)
oc get builds -A -l workshop=low-latency

# Check deployment logs
tail -f /tmp/sno-provision-*/provision-*.log
```

---

## Instance Size Requirements

### Current Configuration (Testing)

| Component | Instance | vCPU | RAM | Notes |
|-----------|----------|------|-----|-------|
| Bastion | t3a.medium | 2 | 4 GB | Runs openshift-install |
| SNO | m5.4xlarge | 16 | 64 GB | All-in-one OpenShift |

### OpenShift Virtualization Requirements

> ⚠️ **Research Needed**: The current `m5.4xlarge` instance may not be optimal for OpenShift Virtualization workloads.

**OpenShift Virtualization (CNV) requires:**
- Bare metal or instances with nested virtualization support
- Minimum 64GB RAM (128GB+ recommended for VMs)
- NVMe/SSD storage for VM disks
- Hardware virtualization (Intel VT-x/AMD-V)

**Recommended instance types for OpenShift Virt:**

| Instance | vCPU | RAM | Network | Nested Virt | Notes |
|----------|------|-----|---------|-------------|-------|
| `m5.metal` | 96 | 384 GB | 25 Gbps | ✅ Full | Best for VMs |
| `m5n.metal` | 96 | 384 GB | 100 Gbps | ✅ Full | Network-optimized |
| `m5zn.metal` | 48 | 192 GB | 100 Gbps | ✅ Full | High single-thread |
| `c5.metal` | 96 | 192 GB | 25 Gbps | ✅ Full | Compute-optimized |
| `m5.8xlarge` | 32 | 128 GB | 10 Gbps | ⚠️ Nested | Lower cost option |

**To change instance type**, edit:
```yaml
# agnosticd-configs/low-latency-workshop-sno/default_vars_ec2.yml
sno_instance_type: m5.metal  # or m5.8xlarge for testing
```

### Cost Considerations

| Instance | Hourly (us-east-2) | Per SNO/Day | 5 Users/Day |
|----------|-------------------|-------------|-------------|
| m5.4xlarge | ~$0.77 | ~$18.50 | ~$92 |
| m5.8xlarge | ~$1.54 | ~$37 | ~$185 |
| m5.metal | ~$4.61 | ~$110 | ~$550 |

> 💡 **Tip**: For testing, use `m5.4xlarge`. For full workshop with VMs, consider `m5.metal` or `m5.8xlarge` with nested virt.

---

## Workshop Content

| Module | Topic | Duration |
|--------|-------|----------|
| 01 | SNO Overview & Architecture | 30 min |
| 02 | RHACM GitOps Integration | 45 min |
| 03 | Baseline Performance Testing | 60 min |
| 04 | OpenShift Virtualization | 45 min |
| 05 | Performance Tuning | 60 min |

---

## User Access Information

After deployment, share with users:

```
═══════════════════════════════════════════════════════════════
  LOW-LATENCY PERFORMANCE WORKSHOP
═══════════════════════════════════════════════════════════════

  OpenShift Console: https://console-openshift-console.apps.{hub-domain}
  
  Username: userN  (user1, user2, ...)
  Password: workshop
  
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
├── agnosticd-configs/           # AgnosticD configurations
│   ├── low-latency-workshop-hub/    # Hub cluster setup
│   └── low-latency-workshop-sno/    # SNO cluster deployment
├── content/                     # Antora workshop content
│   └── modules/ROOT/pages/          # Module documentation
├── devfile.yaml                 # Dev Spaces workspace definition
├── gitops/                      # GitOps resources
│   ├── devspaces/                   # Dev Spaces operator + instance
│   ├── rhacm-operator/              # RHACM operator
│   ├── rhacm-instance/              # MultiClusterHub instance
│   └── workshop-docs/               # BuildConfig for docs
├── workshop-scripts/            # Deployment automation
│   ├── 00-install-rhacm.sh
│   ├── 01-setup-ansible-navigator.sh
│   ├── 02-configure-aws-credentials.sh
│   ├── 03-test-single-sno.sh
│   ├── 05-setup-hub-users.sh
│   ├── 06-provision-user-snos.sh
│   ├── 07-setup-user-devspaces.sh
│   ├── 08-provision-complete-workshop.sh
│   └── 09-setup-module02-rhacm.sh
└── docs/                        # Admin documentation
    ├── ADMIN-DEPLOYMENT.md
    └── USER_WORKSHOP_GUIDE.md
```

---

## Cleanup

### Single User
```bash
# Destroy SNO cluster
./99-destroy-sno.sh workshop-user1

# Remove hub resources
oc delete namespace workshop-user1
```

### Multi-User
```bash
# Destroy all SNO clusters
./99-destroy-all-students.sh 5 user

# Remove hub resources
for i in $(seq 1 5); do
    oc delete namespace workshop-user${i}
done
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run validation: `./utilities/lab-build/validate-build.sh`
4. Submit PR with signed commits (`git commit -s`)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/tosin2013/low-latency-performance-workshop/issues)
- **Docs**: See `docs/` directory
- **AgnosticD**: [RedHatGov/agnosticd](https://github.com/redhat-cop/agnosticd)

