# Low-Latency Performance Workshop - User Guide

Welcome to the Low-Latency Performance Workshop! This guide helps you get started in your Dev Spaces environment.

## Quick Start

### Step 1: Access Dev Spaces

1. Login to OpenShift Console with your credentials:
   - **Username**: `userN` (e.g., user1, user2)
   - **Password**: `workshop`

2. Click the grid icon (9 squares) → **Red Hat OpenShift Dev Spaces**

3. Or go directly to: `https://devspaces.apps.{your-hub-domain}`

### Step 2: Create Your Workspace

1. Click **"Create Workspace"**
2. Enter the repository URL:
   ```
   https://github.com/tosin2013/low-latency-performance-workshop
   ```
3. Branch: `feat/deployment-automation` (or `main`)
4. Click **"Create & Open"**

The workspace takes 2-3 minutes to start.

### Step 3: Access Your Documentation

Your personalized workshop documentation is available at:
```
https://docs-{your-username}.apps.{hub-domain}
```

Example: `https://docs-user1.apps.cluster-xxxx.sandbox.opentlc.com`

> The docs have your SNO cluster URLs and credentials pre-filled!

---

## Your Environment

### Credentials Automatically Available

When your workspace starts, these are pre-configured:

| Item | Location | Notes |
|------|----------|-------|
| SNO Kubeconfig | `/home/user/.kube/config` | Auto-loaded by `oc` |
| SSH Key | `/home/user/.ssh/id_rsa` | For bastion access |
| SNO Info | Environment variables | See below |

### Check Your Setup

In the Dev Spaces terminal, run:

```bash
# Check which cluster you're connected to
oc whoami --show-server

# Should show your SNO cluster URL, NOT the hub
# Example: https://api.workshop-user1.sandbox1234.opentlc.com:6443

# Verify cluster access
oc get nodes
oc get clusterversion
```

### Environment Variables

These are available in your workspace:

```bash
echo $KUBECONFIG          # /home/user/.kube/config
echo $WORKSHOP_HOME       # /projects/workshop
```

---

## Safety Check: Hub vs SNO

⚠️ **Important**: Workshop modules run on your **SNO cluster**, not the hub!

The workspace runs a safety check automatically. You can also run it manually:

```bash
# In Dev Spaces terminal - click "0. Check Cluster Safety" or run:
oc whoami --show-server
```

**If you see the hub cluster URL**, switch to your SNO:
```bash
# Get your SNO credentials from the docs or:
cat /home/user/sno-info/SNO_API 2>/dev/null

# Login to SNO
oc login https://api.workshop-{username}.{domain}:6443 -u kubeadmin -p <password>
```

---

## Workshop Modules

### Accessing Module Content

1. **Option A - Deployed Docs** (Recommended):
   Open your browser to: `https://docs-{username}.apps.{hub-domain}`
   
2. **Option B - Local Docs**:
   In Dev Spaces, build and serve locally:
   ```bash
   # Build docs
   ./utilities/lab-build --skip-validation
   
   # Serve on port 8080
   cd www && python3 -m http.server 8080
   ```
   Then click the "workshop-docs" endpoint in Dev Spaces.

### Module Overview

| Module | Description | Cluster |
|--------|-------------|---------|
| 02 | Operator Setup | Hub (pre-configured) |
| 03 | Baseline Performance | **SNO** |
| 04 | Performance Profile | **SNO** |
| 05+ | Advanced Tuning | **SNO** |

---

## Common Tasks

### SSH to Bastion (if needed)

```bash
# From Dev Spaces terminal
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa \
    ec2-user@bastion.workshop-{username}.{domain}
```

### Run kube-burner Tests

```bash
# Install kube-burner (done automatically on workspace start)
kube-burner version

# Run baseline test
cd /projects/workshop/gitops/kube-burner-configs
kube-burner init -c baseline-config.yml
```

### View Cluster Resources

```bash
# Node status
oc get nodes -o wide

# Performance-related
oc get performanceprofile
oc get tuned -n openshift-cluster-node-tuning-operator

# Check cluster status
oc get nodes
```

---

## Troubleshooting

### "Not logged into any cluster"

Your kubeconfig secret may not have loaded. Try:
```bash
# Check if kubeconfig exists
ls -la /home/user/.kube/

# If missing, login manually (get password from your docs page)
oc login https://api.workshop-{username}.{domain}:6443 -u kubeadmin -p <password>
```

### "Connection refused" or timeout

1. Check if SNO cluster is running:
   - Verify cluster API is accessible: `oc get nodes`
   
2. Verify you're using the right URL (SNO, not hub)

### Commands not found

```bash
# Add local bin to PATH
export PATH=$PATH:/home/user/.local/bin

# Reinstall kube-burner
mkdir -p ~/.local/bin
curl -sL https://github.com/kube-burner/kube-burner/releases/download/v1.17.5/kube-burner-V1.17.5-linux-x86_64.tar.gz | tar xzf - -C ~/.local/bin
```

### SSH "Permission denied"

```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Try with verbose output
ssh -v -i ~/.ssh/id_rsa ec2-user@bastion.workshop-{username}.{domain}
```

---

## Getting Help

- **Workshop Docs**: `https://docs-{username}.apps.{hub-domain}`
- **Dev Spaces Commands**: Click the hamburger menu → Terminal → Run Task
- **Admin Support**: Contact your workshop administrator

---

## Quick Reference

| Resource | How to Access |
|----------|---------------|
| SNO Console | Check your docs page for URL |
| SNO API | `oc whoami --show-server` |
| Hub Console | `https://console-openshift-console.apps.{hub-domain}` |
| Your Docs | `https://docs-{username}.apps.{hub-domain}` |
| Dev Spaces | `https://devspaces.apps.{hub-domain}` |

