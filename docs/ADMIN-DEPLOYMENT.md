# Administrator Deployment Guide

This guide is for **workshop administrators** setting up the Low-Latency Performance Workshop infrastructure.

> **Note**: Users do NOT run these scripts. Users access the workshop through Dev Spaces and follow the personalized documentation deployed to their namespace.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HUB CLUSTER                                  │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌───────────────────┐  ┌───────────────────────┐ │
│  │   RHACM     │  │   Dev Spaces      │  │   User Namespaces     │ │
│  │ (manages    │  │ (user1-devspaces) │  │ workshop-user1        │ │
│  │  SNO        │  │ (user2-devspaces) │  │ workshop-user2        │ │
│  │  clusters)  │  │      ...          │  │       ...             │ │
│  └─────────────┘  └───────────────────┘  └───────────────────────┘ │
│                                                      │              │
│                              ┌───────────────────────┼──────────────┤
│                              │  Each namespace has:  │              │
│                              │  - Docs container     │              │
│                              │  - Kubeconfig secret  │              │
│                              │  - SSH key secret     │              │
│                              │  - SNO info ConfigMap │              │
│                              └───────────────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
          ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
          │ SNO user1   │  │ SNO user2   │  │ SNO userN   │
          │ (AWS EC2)   │  │ (AWS EC2)   │  │ (AWS EC2)   │
          └─────────────┘  └─────────────┘  └─────────────┘
```

## What Users See

Each user:
1. Logs into OpenShift console → `userN` / `workshop`
2. Opens Dev Spaces → https://devspaces.apps.{hub-domain}
3. Creates workspace from `https://github.com/tosin2013/low-latency-performance-workshop`
4. Gets auto-mounted:
   - Kubeconfig for their SNO cluster
   - SSH key for bastion access
5. Accesses personalized docs → `https://docs-userN.apps.{hub-domain}`

---

## Single User Deployment (Testing)

### Prerequisites
```bash
# On admin workstation (NOT in Dev Spaces)
cd /home/lab-user/low-latency-performance-workshop/workshop-scripts

# 1. Setup ansible-navigator
./01-setup-ansible-navigator.sh

# 2. Configure AWS credentials
./02-configure-aws-credentials.sh
```

### Deploy for 1 User
```bash
# 3. Install RHACM (if needed)
./00-install-rhacm.sh

# 4. Setup hub cluster (1 user)
./05-setup-hub-users.sh 1

# 5. Deploy SNO for user1
./03-test-single-sno.sh user1 rhpds

# 6. Update Dev Spaces secrets with actual SNO credentials
./07-setup-user-devspaces.sh 1
```

### Verify
```bash
# Check managed clusters
oc get managedclusters

# Check docs deployment
oc get route docs-user1 -n workshop-user1

# Check secrets
oc get secret user1-kubeconfig -n workshop-user1
```

---

## Multi-User Deployment (Workshop)

### Deploy for N Users
```bash
# One-command deployment for 5 users
./08-provision-complete-workshop.sh 5

# Or step by step:
./00-install-rhacm.sh
./05-setup-hub-users.sh 5
./06-provision-user-snos.sh 5 3    # 5 users, 3 parallel
./07-setup-user-devspaces.sh 5
```

### Monitor Progress
```bash
# Watch SNO deployments
watch -n 30 'oc get managedclusters'

# Check deployment logs
tail -f /tmp/sno-provision-*/provision-*.log
```

---

## What Gets Deployed Per User

| Resource | Location | Purpose |
|----------|----------|---------|
| htpasswd user | cluster | `userN` / `workshop` login |
| Namespace | `workshop-userN` | User's workshop resources |
| Docs Deployment | `workshop-userN` | Personalized Antora docs |
| Docs Route | `docs-userN.apps.*` | Public URL to docs |
| Kubeconfig Secret | `workshop-userN` | Auto-mounted to Dev Spaces |
| SSH Key Secret | `workshop-userN` | Auto-mounted to Dev Spaces |
| SNO Info ConfigMap | `workshop-userN` | Cluster URLs and info |
| SNO Cluster | AWS | Managed by RHACM |

---

## User Access Information

After deployment, users receive:

```
═══════════════════════════════════════════════════════════════
  WORKSHOP ACCESS - userN
═══════════════════════════════════════════════════════════════
  
  OpenShift Console: https://console-openshift-console.apps.{hub-domain}
  Username: userN
  Password: workshop
  
  Dev Spaces: https://devspaces.apps.{hub-domain}
  
  Documentation: https://docs-userN.apps.{hub-domain}
  
═══════════════════════════════════════════════════════════════
```

---

## Cleanup

### Remove User SNO Clusters
```bash
for i in $(seq 1 5); do
    ./destroy-sno.sh workshop-user${i}
done
```

### Remove Hub Resources
```bash
# Remove user namespaces
for i in $(seq 1 5); do
    oc delete namespace workshop-user${i}
done

# Remove htpasswd
oc delete secret htpasswd-workshop-secret -n openshift-config
```

---

## Troubleshooting

### SNO not appearing in RHACM
```bash
# Check managed cluster status
oc get managedcluster workshop-user1 -o yaml | grep -A10 status

# Check klusterlet on SNO
KUBECONFIG=~/agnosticd-output/workshop-user1/kubeconfig \
  oc get pods -n open-cluster-management-agent
```

### Docs container not starting
```bash
# Check init container logs (builds Antora)
oc logs -n workshop-user1 deployment/workshop-docs -c build-docs

# Check main container
oc logs -n workshop-user1 deployment/workshop-docs
```

### Dev Spaces secrets not mounting
```bash
# Verify secret labels
oc get secret user1-kubeconfig -n workshop-user1 -o yaml | grep -A5 labels

# Should have:
#   controller.devfile.io/mount-to-devworkspace: "true"
#   controller.devfile.io/watch-secret: "true"
```

