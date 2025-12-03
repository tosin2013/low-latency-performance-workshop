# Multi-User Workshop Deployment Guide

This guide walks through deploying the Low-Latency Performance Workshop for **multiple users** (configurable, default 5 users).

## Overview

This deployment creates:
- N SNO (Single Node OpenShift) clusters (one per user)
- RHACM on the hub cluster (if not already installed)
- Dev Spaces with per-user workspaces
- htpasswd authentication (user1-userN with workshop password)
- Per-user namespaces with mounted credentials

## Prerequisites

### Hub Cluster Requirements
- OpenShift 4.14+ cluster (hub)
- cluster-admin access
- At least 32GB RAM for RHACM + Dev Spaces

### AWS Requirements
- AWS account with sufficient quota
- Per SNO cluster: 1 x m6i.2xlarge (8 vCPU, 32GB RAM)
- For 5 users: ~40 vCPUs, 160GB RAM total

### Workstation Requirements
- `oc` CLI installed and logged into hub cluster
- `ansible-navigator` installed
- AWS credentials configured
- OpenShift pull secret

## Deployment Steps

### Step 0: Initial Setup

```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# Setup ansible-navigator
./01-setup-ansible-navigator.sh

# Configure AWS credentials
./02-configure-aws-credentials.sh
```

### Step 1: Install RHACM

```bash
# Install RHACM (idempotent - skip if already installed)
./00-install-rhacm.sh
```

Wait for RHACM status to be "Running" (~10-15 minutes).

### Step 2: Setup Hub Cluster Users

```bash
# Create 5 users (user1-user5)
./05-setup-hub-users.sh 5

# Or create 10 users
./05-setup-hub-users.sh 10
```

This creates:
- `user1` through `userN` credentials (password: workshop)
- `admin` user (password: redhat123)
- `workshop-user1` through `workshop-userN` namespaces
- Dev Spaces operator and CheCluster

### Step 3: Provision SNO Clusters (Parallel)

```bash
# Deploy 5 SNO clusters, 3 in parallel (default)
./06-provision-user-snos.sh 5

# Or with custom parallelism
./06-provision-user-snos.sh 5 2   # 5 users, 2 parallel
./06-provision-user-snos.sh 10 5  # 10 users, 5 parallel
```

**Estimated time:** 
- 5 users (3 parallel): ~90 minutes
- 10 users (5 parallel): ~90 minutes

Monitor progress:
```bash
# Watch all deployment logs
tail -f /tmp/sno-provision-*/provision-*.log

# Check RHACM for imported clusters
watch -n 30 'oc get managedclusters'
```

### Step 4: Setup Dev Spaces Secrets

```bash
# Update all user secrets with SNO kubeconfigs
./07-setup-user-devspaces.sh 5
```

### Step 5: Setup Module 02 (RHACM Integration)

```bash
# Configure ArgoCD integration and deploy operators
./09-setup-module02-rhacm.sh
```

## Complete Deployment (All-in-One)

For automated end-to-end deployment:

```bash
# Deploy complete workshop for 5 users
./08-provision-complete-workshop.sh 5
```

This runs all steps in sequence.

## Verification

### Check All Managed Clusters:
```bash
oc get managedclusters

# Expected output:
# NAME              HUB ACCEPTED   MANAGED CLUSTER URLS                                    JOINED   AVAILABLE
# local-cluster     true           https://api.hub-cluster.example.com:6443               True     True
# workshop-user1    true           https://api.workshop-user1.example.com:6443            True     True
# workshop-user2    true           https://api.workshop-user2.example.com:6443            True     True
# ...
```

### Check Dev Spaces:
```bash
oc get checluster -n openshift-devspaces

# Check workspaces
oc get devworkspaces -A
```

### Check User Namespaces:
```bash
oc get namespaces | grep workshop-user
```

## User Access

### For Each User (user1, user2, etc.):

| Resource | Value |
|----------|-------|
| Username | `userN` (e.g., user1, user2) |
| Password | `workshop` |
| Namespace | `workshop-userN` |
| SNO Cluster | `workshop-userN` |

### Login Steps:

1. **OpenShift Console:**
   ```
   https://console-openshift-console.apps.<hub-domain>
   ```

2. **Dev Spaces Dashboard:**
   ```
   https://devspaces.apps.<hub-domain>
   ```

3. **Create Workspace:**
   - Repository: `https://github.com/tosin2013/low-latency-performance-workshop`
   - Branch: `feat/deployment-automation`

4. **In Dev Spaces Terminal:**
   ```bash
   # Kubeconfig is auto-mounted
   oc get nodes
   oc whoami --show-server
   ```

## Admin Access

| Resource | Credentials |
|----------|-------------|
| Hub Console | `admin` / `redhat123` |
| Hub kubeadmin | Check original cluster deployment |
| RHACM Console | Same as hub console |

### RHACM Console:
```bash
oc get route multicloud-console -n open-cluster-management -o jsonpath='{.spec.host}'
```

## Per-User SNO Access

### Get User's SNO kubeconfig:
```bash
# For user1
export KUBECONFIG=~/agnosticd-output/workshop-user1/kubeconfig

# For user2
export KUBECONFIG=~/agnosticd-output/workshop-user2/kubeconfig
```

### Get kubeadmin password:
```bash
cat ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_kubeadmin-password
```

### SSH to Bastion:
```bash
ssh -F ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_ssh_conf bastion
```

## Scaling

### Add More Users Later:

```bash
# Current users: 5
# Add users 6-10:

# 1. Update hub (adds user6-user10)
./05-setup-hub-users.sh 10

# 2. Deploy additional SNOs (only deploys missing ones)
./06-provision-user-snos.sh 10 3

# 3. Update secrets
./07-setup-user-devspaces.sh 10
```

## Cleanup

### Remove All SNO Clusters:
```bash
for i in $(seq 1 5); do
    ./destroy-sno.sh workshop-user${i}
done
```

### Remove User Resources:
```bash
# Remove user namespaces
for i in $(seq 1 5); do
    oc delete namespace workshop-user${i}
done

# Remove htpasswd users
oc delete secret htpasswd-workshop-secret -n openshift-config
```

### Uninstall RHACM:
```bash
oc delete multiclusterhub multiclusterhub -n open-cluster-management
oc delete subscription advanced-cluster-management -n open-cluster-management
```

## Troubleshooting

### Some SNO Deployments Failed:
```bash
# Check which failed
cat /tmp/sno-provision-*/deployment-summary.txt

# Retry specific user
./03-test-single-sno.sh user3 rhpds
```

### Dev Spaces Workspace Issues:
```bash
# Check operator status
oc get csv -n openshift-devspaces

# Check CheCluster
oc describe checluster devspaces -n openshift-devspaces

# Restart workspace
oc delete devworkspace <workspace-name> -n <user>-devspaces
```

### RHACM Not Importing Clusters:
```bash
# Check managed cluster conditions
oc get managedcluster workshop-user1 -o yaml | grep -A 20 conditions

# Check klusterlet on SNO
KUBECONFIG=~/agnosticd-output/workshop-user1/kubeconfig \
  oc get pods -n open-cluster-management-agent
```

### AWS Quota Issues:
```bash
# Check current usage
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceType' | sort | uniq -c

# Request quota increase for m6i.2xlarge in your region
```

## Quick Reference

| Script | Purpose |
|--------|---------|
| `00-install-rhacm.sh` | Install RHACM on hub |
| `01-setup-ansible-navigator.sh` | Setup ansible-navigator |
| `02-configure-aws-credentials.sh` | Configure AWS credentials |
| `03-test-single-sno.sh` | Deploy single SNO |
| `05-setup-hub-users.sh N` | Create N users on hub |
| `06-provision-user-snos.sh N P` | Deploy N SNOs, P parallel |
| `07-setup-user-devspaces.sh N` | Update Dev Spaces secrets |
| `08-provision-complete-workshop.sh N` | Full deployment |
| `09-setup-module02-rhacm.sh` | Setup Module 02 |

## Cost Estimate (AWS)

| Resource | Per User | 5 Users | 10 Users |
|----------|----------|---------|----------|
| SNO (m6i.2xlarge) | ~$0.38/hr | ~$1.90/hr | ~$3.80/hr |
| Bastion (t3.medium) | ~$0.04/hr | ~$0.20/hr | ~$0.40/hr |
| Storage (gp3) | ~$0.08/hr | ~$0.40/hr | ~$0.80/hr |
| **Total** | **~$0.50/hr** | **~$2.50/hr** | **~$5.00/hr** |

*Prices vary by region. Estimate for us-east-2.*

