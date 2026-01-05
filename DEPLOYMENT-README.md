# Low-Latency Performance Workshop

A hands-on workshop for understanding and optimizing low-latency workloads on OpenShift using:
- Single Node OpenShift (SNO)
- OpenShift Virtualization
- Performance tuning and real-time kernel configurations

## Quick Start for Administrators

### Deployment

| Command | Time | Purpose |
|---------|------|---------|
| `./scripts/workshop-setup.sh` | ~5 min setup | Automated setup and configuration |
| `./scripts/deploy-sno.sh student1 sandbox1234` | ~45 min | Deploy SNO cluster |

---

## AgnosticD v2 Deployment

**Simplified deployment using AgnosticD V2 - no hub cluster required!**

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

## Expected Output

After successful deployment, each user will have:

### Per-User Resources

| Resource | Description |
|----------|-------------|
| SNO Cluster | Single Node OpenShift on AWS |
| Bastion | t3a.medium instance for cluster management |
| Workloads | Cert Manager, OpenShift Virtualization, Showroom |

### Output Files (per user)

```
~/Development/agnosticd-v2-output/studentX/
├── openshift-cluster_studentX_kubeconfig       # SNO cluster access
├── openshift-cluster_studentX_kubeadmin-password
└── provision-user-info.yaml                    # User connection info
```

### Installed Operators (on each SNO)

- OpenShift Virtualization
- SR-IOV Network Operator (optional)
- Node Tuning Operator (built-in)

### Estimated Deployment Time

| Scenario | Time |
|----------|------|
| Single SNO cluster | ~45-60 minutes |

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
# agnosticd-v2-vars/low-latency-sno-aws.yml
control_plane_instance_type: m5.metal  # or m5.8xlarge for testing
```

### Cost Considerations

| Instance | Hourly (us-east-2) | Per SNO/Day | 5 Users/Day |
|----------|-------------------|-------------|-------------|
| m5.4xlarge | ~$0.77 | ~$18.50 | ~$92 |
| m5.8xlarge | ~$1.54 | ~$37 | ~$185 |
| m5.metal | ~$4.61 | ~$110 | ~$550 |

---

## User Access Information

After deployment, the user will have access to:

```
═══════════════════════════════════════════════════════════════
  LOW-LATENCY PERFORMANCE WORKSHOP
═══════════════════════════════════════════════════════════════

  SNO Console: https://console-openshift-console.apps.<cluster-domain>

  Showroom Docs: https://showroom.<cluster-domain>

  Bastion SSH: ssh ec2-user@bastion.<cluster-domain>

═══════════════════════════════════════════════════════════════
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AWS (us-east-2)                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                     SNO Cluster (studentX)                        │  │
│  │                                                                   │  │
│  │  ┌─────────────┐  ┌──────────────────┐  ┌─────────────────────┐  │  │
│  │  │   Bastion   │  │   SNO Node       │  │   Showroom          │  │  │
│  │  │ t3a.medium  │  │   m5.4xlarge     │  │   (Workshop Docs)   │  │  │
│  │  │             │  │                  │  │                     │  │  │
│  │  │ - SSH       │  │  Operators:      │  │  - Antora content   │  │  │
│  │  │ - oc CLI    │  │  - Virt (CNV)    │  │  - User guide       │  │  │
│  │  │             │  │  - Node Tuning   │  │                     │  │  │
│  │  └─────────────┘  └──────────────────┘  └─────────────────────┘  │  │
│  │                                                                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
low-latency-performance-workshop/
├── README.adoc                  # Project overview
├── devfile.yaml                 # Dev Spaces workspace definition
├── agnosticd-v2-vars/           # AgnosticD v2 configurations
│   ├── low-latency-sno-aws.yml      # SNO cluster config
│   └── README.md                    # Config documentation
├── scripts/                     # AgnosticD v2 deployment scripts
│   ├── workshop-setup.sh            # Full automated setup
│   ├── deploy-sno.sh                # Deploy SNO cluster
│   ├── destroy-sno.sh               # Destroy SNO cluster
│   └── status-sno.sh                # Check cluster status
├── content/                     # Antora workshop content
│   └── modules/ROOT/pages/          # Module documentation
├── gitops/                      # GitOps resources
│   ├── openshift-virtualization/    # OpenShift Virtualization operator
│   ├── kube-burner-configs/         # Performance testing configs
│   └── ...
└── docs/                        # Additional documentation
    └── WORKSHOP_SETUP.md            # Complete setup guide
```

---

## Cleanup

### Destroy SNO Cluster

```bash
# Destroy the SNO cluster
./scripts/destroy-sno.sh student1 sandbox1234
```

---

## Troubleshooting

### Check SNO Status

```bash
# Check cluster status
./scripts/status-sno.sh student1 sandbox1234

# Direct access (if kubeconfig available)
export KUBECONFIG=~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig
oc get nodes
```

### View Deployment Logs

```bash
# Check AgnosticD v2 logs
ls -la ~/Development/agnosticd-v2-output/student1/
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Deployment fails | Check AWS credentials in secrets.yml |
| Cluster not accessible | Verify security groups and bastion connectivity |
| Operators not installing | Check workload configuration in agnosticd-v2-vars |

---

## Additional Documentation

- **Setup Guide**: [docs/WORKSHOP_SETUP.md](docs/WORKSHOP_SETUP.md) - Complete setup guide
- **Project Overview**: [README.adoc](README.adoc)
- **AgnosticD v2 Reference**: [agnosticd/agnosticd-v2](https://github.com/agnosticd/agnosticd-v2)

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes with actual workshop environment
4. Submit PR with signed commits (`git commit -s`)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/tosin2013/low-latency-performance-workshop/issues)
- **Docs**: See [docs/WORKSHOP_SETUP.md](docs/WORKSHOP_SETUP.md) for detailed setup guide
