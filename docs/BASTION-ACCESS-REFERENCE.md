# Bastion Access Reference

This document contains **verified** information about bastion host access for the Low-Latency Performance Workshop.

> **Last Verified**: January 7, 2026 - Successfully deployed and tested with AgnosticD v2

## Bastion Connection Details

### Hostname Format
- **Pattern**: `bastion.{username}.{subdomain}`
- **Example**: `bastion.student1.sandbox5466.opentlc.com`

### SSH Access

| Field | Value |
|-------|-------|
| **Username** | `lab-user` |
| **Password** | Provided by administrator (from `provision-user-info.yaml`) |
| **Authentication** | Password-based |

### SSH Command

```bash
ssh lab-user@bastion.<username>.<subdomain>
```

**Example:**
```bash
ssh lab-user@bastion.student1.sandbox5466.opentlc.com
# Enter password when prompted
```

## Verified Bastion Environment

### Pre-configured Tools (Verified ✅)

| Tool | Location | Status |
|------|----------|--------|
| `oc` | `/usr/bin/oc` | ✅ Pre-installed |
| `kubectl` | `/usr/bin/kubectl` | ✅ Pre-installed |
| KUBECONFIG | `~/.kube/config` | ✅ Pre-configured |

### Cluster Authentication (Verified ✅)

The bastion is pre-configured with cluster-admin access:

```bash
$ oc whoami
system:admin

$ oc get nodes
NAME                                       STATUS   ROLES                         AGE   VERSION
ip-10-0-53-97.us-east-2.compute.internal   Ready    control-plane,master,worker   42m   v1.33.6
```

### ec2-user Access

The `ec2-user` account (for SSH key authentication) has:
- SSH key-based login (configured via `host_ssh_authorized_keys`)
- Full kubeconfig at `~/ocp/auth/kubeconfig`
- kubeadmin password at `~/ocp/auth/kubeadmin-password`

## Output Files Location

After deployment, connection information is in:

```
~/Development/agnosticd-v2-output/{username}/
├── openshift-cluster_{username}_kubeconfig         # SNO cluster kubeconfig
├── openshift-cluster_{username}_kubeadmin-password # kubeadmin password
├── ssh_provision_{username}                        # SSH private key (for ec2-user)
└── provision-user-info.yaml                        # Complete connection info
```

### Example provision-user-info.yaml

```yaml
---
- "You can access your bastion via SSH:\nssh lab-user@bastion.student1.sandbox5466.opentlc.com\n\nUse password 'xxxxxxxx' when prompted.\n"
- "OpenShift Console: https://console-openshift-console.apps.ocp.student1.sandbox5466.opentlc.com\nOpenShift API for command line 'oc' client: https://api.ocp.student1.sandbox5466.opentlc.com:6443\n"
- "Lab instructions: https://workshop-docs-low-latency-workshop.apps.ocp.student1.sandbox5466.opentlc.com/"
```

## OpenShift Access Details

### Console & API URLs

| Resource | URL Pattern |
|----------|-------------|
| Console | `https://console-openshift-console.apps.ocp.{username}.{subdomain}` |
| API | `https://api.ocp.{username}.{subdomain}:6443` |
| Showroom Docs | `https://workshop-docs-low-latency-workshop.apps.ocp.{username}.{subdomain}/` |

### Credentials

| User | Password Location |
|------|-------------------|
| `kubeadmin` | On bastion: `~/ocp/auth/kubeadmin-password` |
| `lab-user` (bastion) | From `provision-user-info.yaml` |

## Installed Operators (Verified ✅)

```bash
$ oc get csv -A | grep -E 'cert-manager|virtualization'
cert-manager-operator   cert-manager-operator.v1.18.0   Succeeded
openshift-cnv           kubevirt-hyperconverged-operator.v4.20.3   Succeeded
```

### OpenShift Virtualization Status

```bash
$ oc get hyperconverged -n openshift-cnv -o jsonpath='{.items[0].status.conditions}' | jq
ReconcileComplete: True
Available: True
Progressing: False
Degraded: False
```

## Access Information Flow

1. **Administrator deploys cluster** using `./scripts/deploy-sno.sh {username} {sandbox}`
2. **Output files generated** in `~/Development/agnosticd-v2-output/{username}/`
3. **Administrator provides** to students:
   - Bastion hostname: `bastion.{username}.{subdomain}`
   - Password: From `provision-user-info.yaml`
   - (Optional) Console URL
4. **Student connects** via SSH: `ssh lab-user@bastion.xxx.xxx`
5. **Student runs commands** directly on bastion (oc CLI pre-configured)

## Notes

- **lab-user** uses password authentication (most common for workshops)
- **ec2-user** uses SSH key authentication (for admins)
- Bastion has direct network access to SNO cluster
- All workshop commands can be run from bastion without additional setup
- OpenShift Virtualization works on `m5.4xlarge` (uses software emulation)

