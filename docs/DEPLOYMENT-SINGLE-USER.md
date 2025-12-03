# Single User Deployment Guide

This guide walks through deploying the Low-Latency Performance Workshop for a **single user (user1)** for end-to-end testing.

## Overview

This deployment creates:
- 1 SNO (Single Node OpenShift) cluster for user1
- RHACM on the hub cluster (if not already installed)
- Dev Spaces for user1 to interact with their SNO
- htpasswd authentication with user1/workshop credentials

## Prerequisites

### Hub Cluster Requirements
- OpenShift 4.14+ cluster (hub)
- cluster-admin access
- At least 16GB RAM available for RHACM

### Workstation Requirements
- `oc` CLI installed and logged into hub cluster
- `ansible-navigator` installed (or run setup script)
- AWS credentials configured
- OpenShift pull secret

## Step-by-Step Deployment

### Step 0: Initial Setup

```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# Setup ansible-navigator (if not already done)
./01-setup-ansible-navigator.sh

# Configure AWS credentials
./02-configure-aws-credentials.sh
```

### Step 1: Install RHACM (if not already installed)

```bash
# Check if RHACM is installed
oc get multiclusterhub -n open-cluster-management

# If not installed, run:
./00-install-rhacm.sh
```

Wait for RHACM to be fully ready (Status: Running). This takes ~10-15 minutes.

### Step 2: Setup Hub Cluster for 1 User

```bash
# Create user1 with htpasswd auth, install Dev Spaces, create namespace
./05-setup-hub-users.sh 1
```

This creates:
- `user1` / `workshop` credentials
- `workshop-user1` namespace
- Dev Spaces operator and CheCluster instance

### Step 3: Deploy SNO Cluster for user1

```bash
# Deploy single SNO cluster
./03-test-single-sno.sh user1 rhpds
```

**Estimated time:** 45-60 minutes

Monitor progress:
```bash
# Watch deployment logs
tail -f ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_log/*.log
```

### Step 4: Verify Deployment

```bash
# Check SNO cluster is imported into RHACM
oc get managedclusters

# Should show:
# NAME              HUB ACCEPTED   MANAGED CLUSTER URLS                                           JOINED   AVAILABLE   AGE
# local-cluster     true           https://api.cluster-xxxx.sandbox.opentlc.com:6443             True     True        1h
# workshop-user1    true           https://api.workshop-user1.sandbox.opentlc.com:6443           True     True        30m
```

### Step 5: Update Dev Spaces Secrets

```bash
# Copy kubeconfig to user's Dev Spaces secret
./07-setup-user-devspaces.sh 1
```

## Testing the Workshop

### As user1:

1. **Login to OpenShift Console:**
   ```
   https://console-openshift-console.apps.<hub-cluster-domain>
   Username: user1
   Password: workshop
   ```

2. **Access Dev Spaces:**
   ```
   https://devspaces.apps.<hub-cluster-domain>
   ```

3. **Create Workspace:**
   - Click "Create Workspace"
   - Enter repository URL: `https://github.com/tosin2013/low-latency-performance-workshop`
   - Branch: `feat/deployment-automation`
   - Click "Create & Open"

4. **Verify SNO Access:**
   In the Dev Spaces terminal:
   ```bash
   # Should automatically use mounted kubeconfig
   oc get nodes
   oc get clusterversion
   ```

## Accessing the SNO Cluster Directly

### From workstation:
```bash
export KUBECONFIG=~/agnosticd-output/workshop-user1/kubeconfig
oc get nodes
```

### SNO Console:
```
https://console-openshift-console.apps.workshop-user1.<subdomain>
Username: kubeadmin
Password: <check ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_kubeadmin-password>
```

### SSH to Bastion:
```bash
ssh -F ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_ssh_conf bastion
```

## Running Workshop Modules

### Module 02: RHACM Setup
Already automated by the deployment. Verify:
```bash
oc get managedclusters
oc get managedclustersets
```

### Module 03: Baseline Performance
In Dev Spaces, run:
```bash
# From the devfile commands panel or terminal
kube-burner init -c workloads/node-density/node-density.yaml
```

## Cleanup

### Remove SNO Cluster:
```bash
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts
./destroy-sno.sh workshop-user1
```

### Remove user1 resources:
```bash
oc delete namespace workshop-user1
oc delete secret htpasswd-workshop-secret -n openshift-config
```

## Troubleshooting

### SNO deployment failed
```bash
# Check logs
cat ~/agnosticd-output/workshop-user1/low-latency-workshop-sno_workshop-user1_log/*.log | tail -100

# Retry deployment
./03-test-single-sno.sh user1 rhpds
```

### Dev Spaces workspace won't start
```bash
# Check CheCluster status
oc get checluster devspaces -n openshift-devspaces -o yaml

# Check operator logs
oc logs -n openshift-devspaces deployment/devspaces-operator
```

### RHACM not importing SNO
```bash
# Check managed cluster status
oc get managedcluster workshop-user1 -o yaml

# Check klusterlet on SNO
KUBECONFIG=~/agnosticd-output/workshop-user1/kubeconfig oc get pods -n open-cluster-management-agent
```

## Quick Reference

| Resource | URL/Command |
|----------|-------------|
| Hub Console | `oc whoami --show-console` |
| Dev Spaces | `https://devspaces.apps.<domain>` |
| SNO Console | `https://console-openshift-console.apps.workshop-user1.<domain>` |
| SNO kubeconfig | `~/agnosticd-output/workshop-user1/kubeconfig` |
| User credentials | `user1` / `workshop` |
| Admin credentials | `admin` / `redhat123` |

