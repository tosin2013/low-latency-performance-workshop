# Administrator Deployment Guide

This guide is for **workshop administrators** setting up the Low-Latency Performance Workshop infrastructure using AgnosticD v2.

## Architecture Overview

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

## What Users Get

Each user gets:
1. A dedicated SNO cluster on AWS
2. Bastion host with SSH access
3. Workshop documentation via Showroom
4. Pre-installed operators (OpenShift Virtualization, Node Tuning)

---

## Deployment Steps

### 1. Prerequisites Setup

```bash
# Clone the workshop repository
cd ~/Development
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
cd low-latency-performance-workshop

# Run automated setup
./scripts/workshop-setup.sh
```

### 2. Configure Secrets

Edit `~/Development/agnosticd-v2-secrets/secrets.yml`:
- Add OpenShift pull secret from console.redhat.com
- Configure Satellite or RHN repositories

Create `~/Development/agnosticd-v2-secrets/secrets-sandboxXXX.yml`:
- Add AWS credentials from demo.redhat.com
- Replace XXX with your sandbox number

Edit `agnosticd-v2-vars/low-latency-sno-aws.yml`:
- Update `cloud_tags.owner` with your email
- Add `host_ssh_authorized_keys` with your GitHub username

### 3. Deploy SNO Cluster

```bash
# Deploy a cluster for student1
./scripts/deploy-sno.sh student1 sandbox1234
```

### 4. Verify Deployment

```bash
# Check cluster status
./scripts/status-sno.sh student1 sandbox1234

# Set kubeconfig
export KUBECONFIG=~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig

# Verify nodes
oc get nodes
```

---

## Output Files

After deployment, find output at:

```
~/Development/agnosticd-v2-output/studentX/
├── openshift-cluster_studentX_kubeconfig           # SNO cluster access
├── openshift-cluster_studentX_kubeadmin-password   # Admin password
└── provision-user-info.yaml                        # User connection info
```

---

## User Access Information

After deployment, users receive:

```
═══════════════════════════════════════════════════════════════
  WORKSHOP ACCESS - studentX
═══════════════════════════════════════════════════════════════
  
  SNO Console: https://console-openshift-console.apps.<cluster-domain>
  
  Showroom Docs: https://showroom.<cluster-domain>
  
  Bastion SSH: ssh ec2-user@bastion.<cluster-domain>
  
═══════════════════════════════════════════════════════════════
```

---

## Cleanup

### Destroy SNO Cluster

```bash
./scripts/destroy-sno.sh student1 sandbox1234
```

---

## Troubleshooting

### Deployment Fails

```bash
# Check AgnosticD logs
ls -la ~/Development/agnosticd-v2-output/student1/

# Verify AWS credentials
cat ~/Development/agnosticd-v2-secrets/secrets-sandbox1234.yml
```

### Cluster Not Accessible

```bash
# Check bastion connectivity
ssh -i ~/.ssh/id_rsa ec2-user@bastion.<cluster-domain>

# Check kubeconfig
oc --kubeconfig=~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig get nodes
```

### Operators Not Installing

Check the workload configuration in `agnosticd-v2-vars/low-latency-sno-aws.yml` and verify that the operators are listed in the workloads section.
