# User Quick Start Guide

Welcome to the Low-Latency Performance Workshop! This guide will help you get started quickly.

## Prerequisites

You should have received:
- **Username**: `studentN` (e.g., student1, student2)
- **Password**: `workshop`
- **OpenShift Console URL**
- **Dev Spaces URL**

## Step 1: Login to OpenShift Console

1. Open the **OpenShift Console URL** in your browser
2. Click **workshop-htpasswd** identity provider
3. Enter your credentials:
   - Username: `studentN`
   - Password: `workshop`

## Step 2: Access Dev Spaces

1. In the OpenShift console, click the app launcher (grid icon) in the top-right
2. Select **Red Hat OpenShift Dev Spaces**
3. Or navigate directly to: `https://devspaces.<cluster-domain>`

## Step 3: Start Your Workshop Workspace

1. In Dev Spaces dashboard, you have two options:

### Option A: Create from Devfile URL (Recommended)

1. Click **Create Workspace**
2. Enter the Git repository URL:
   ```
   https://github.com/tosin2013/low-latency-performance-workshop.git
   ```
3. Click **Create & Open**

### Option B: Import from Git

1. Click **Create Workspace** → **Import from Git**
2. Enter: `https://github.com/tosin2013/low-latency-performance-workshop.git`
3. Click **Create & Open**

## Step 4: Verify Your Environment

Once your workspace starts (may take 2-3 minutes), open the terminal:

1. Click **Terminal** → **New Terminal** (or press `` Ctrl+` ``)

2. Verify SNO cluster access:
   ```bash
   oc get nodes
   ```
   
   You should see your SNO node listed.

3. Check cluster info:
   ```bash
   oc cluster-info
   ```

4. Verify SSH key is available:
   ```bash
   ls -la ~/.ssh/id_rsa
   ```

## Step 5: Access Workshop Documentation

Your personalized documentation is available at:
```
https://docs-studentN.<cluster-domain>
```

Replace `studentN` with your actual username (e.g., `docs-student1`).

## Your Environment

### What's Pre-Configured

| Resource | Location |
|----------|----------|
| Kubeconfig | `/home/user/.kube/config` (auto-mounted) |
| SSH Key | `/home/user/.ssh/id_rsa` (auto-mounted) |
| Workshop Repo | `/projects/workshop` |
| KUBECONFIG env | Set automatically |

### Your SNO Cluster

| Resource | Value |
|----------|-------|
| Cluster Name | `workshop-studentN` |
| API URL | `https://api.workshop-studentN.<domain>:6443` |
| Console | `https://console-openshift-console.apps.workshop-studentN.<domain>` |

### Commands You Can Run

```bash
# Check your SNO cluster
oc get nodes
oc get pods -A

# Check cluster operators
oc get co

# SSH to bastion (if needed)
ssh -i ~/.ssh/id_rsa ec2-user@bastion.workshop-studentN.<domain>

# View your namespace on hub cluster
oc get all -n workshop-studentN
```

## Workshop Modules

The workshop consists of the following modules:

1. **Module 01**: Introduction to Low-Latency Workloads
2. **Module 02**: RHACM Setup (pre-configured for you)
3. **Module 03**: Baseline Performance Testing
4. **Module 04**: Performance Profiles
5. **Module 05**: Low-Latency Virtualization
6. **Module 06**: Advanced Tuning

### Starting Module 02

Module 02 covers OpenShift Virtualization setup and configuration. Follow the workshop documentation for step-by-step instructions.

## Troubleshooting

### "oc" command not working

Make sure `KUBECONFIG` is set:
```bash
export KUBECONFIG=/home/user/.kube/config
oc get nodes
```

### Cannot connect to SNO cluster

1. Check if kubeconfig exists:
   ```bash
   cat ~/.kube/config
   ```

2. If it shows "Placeholder", your SNO may not be ready yet. Contact the workshop admin.

### SSH key not found

1. Check if SSH key exists:
   ```bash
   cat ~/.ssh/id_rsa
   ```

2. If it shows "Placeholder", your SNO may not be ready yet.

### Workspace won't start

1. Try refreshing the page
2. Check if you have another workspace running (limit: 1 per user)
3. Stop any running workspaces and try again

### Permission denied errors

Make sure you're working in your assigned namespace:
```bash
# Your namespace is workshop-studentN
oc project workshop-studentN
```

## Getting Help

- **Workshop Documentation**: See the personalized docs URL
- **Workshop Admin**: Contact your instructor
- **Repository**: https://github.com/tosin2013/low-latency-performance-workshop

## Quick Reference

### Useful Commands

```bash
# Check nodes
oc get nodes

# Check pods in all namespaces
oc get pods -A

# Check cluster operators
oc get co

# Check performance profile (Module 04)
oc get performanceprofile

# Check SR-IOV (Module 05)
oc get sriovnetworknodestates -n openshift-sriov-network-operator

# Check virtualization (Module 05)
oc get vms -A
```

### Keyboard Shortcuts (Dev Spaces)

| Shortcut | Action |
|----------|--------|
| `Ctrl+`` | Open terminal |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+P` | Quick open file |
| `Ctrl+S` | Save file |
| `Ctrl+Shift+E` | File explorer |

## Workshop Tips

1. **Save your work**: Dev Spaces persists your files, but commit important changes to git

2. **Use the terminal**: Most workshop exercises are CLI-based

3. **Check logs**: When something fails, check the logs:
   ```bash
   oc logs <pod-name> -n <namespace>
   ```

4. **Take notes**: Use the workspace to create your own notes files

5. **Ask questions**: Don't hesitate to ask the instructor!

---

Good luck with the workshop! 🚀

