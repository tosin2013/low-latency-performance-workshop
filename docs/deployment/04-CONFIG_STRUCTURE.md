# AgnosticD v2 Config Structure

## Overview

Our workshop uses AgnosticD v2 to provision Single Node OpenShift clusters on AWS. The configuration is defined in `agnosticd-v2-vars/low-latency-sno-aws.yml`.

## Directory Structure

```
low-latency-performance-workshop/
├── agnosticd-v2-vars/               # Workshop configuration
│   ├── low-latency-sno-aws.yml      # SNO cluster config
│   └── README.md                    # Config documentation
├── scripts/                         # Deployment scripts
│   ├── workshop-setup.sh            # Full automated setup
│   ├── deploy-sno.sh                # Deploy SNO cluster
│   ├── destroy-sno.sh               # Destroy SNO cluster
│   └── status-sno.sh                # Check cluster status

~/Development/                       # External directories (created by setup)
├── agnosticd-v2/                    # AgnosticD v2 repository
├── agnosticd-v2-secrets/            # Secrets files (not in git)
│   ├── secrets.yml                  # Pull secret, satellite config
│   └── secrets-sandboxXXX.yml       # AWS credentials per sandbox
└── agnosticd-v2-output/             # Deployment outputs
    └── studentX/                    # Per-user output files
```

## Key Configuration File

### agnosticd-v2-vars/low-latency-sno-aws.yml

This is the main configuration file for SNO deployments:

```yaml
---
# Cluster identification
guid: "{{ _guid }}"
cloud_tags:
  guid: "{{ _guid }}"
  owner: your-email@redhat.com

# Platform
platform: aws
region: us-east-2

# OpenShift version
openshift_release: "4.20"

# Instance sizing
control_plane_instance_type: m5.4xlarge
bastion_instance_type: t3a.medium

# Workloads to install
workloads:
  - name: ocp4_workload_cert_manager_operator
  - name: ocp4_workload_openshift_virtualization
  - name: ocp4_workload_showroom
    vars:
      showroom_user: student
```

## Required Variables

### In secrets.yml

```yaml
---
# OpenShift pull secret (required)
ocp4_pull_secret: '{"auths":{...}}'

# SSH keys (optional - can use GitHub keys)
host_ssh_authorized_keys:
  - github:yourusername
```

### In secrets-sandboxXXX.yml

```yaml
---
# AWS credentials for sandbox
aws_access_key_id: AKIAXXXXXXXXXXXXXXXX
aws_secret_access_key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## How Deployment Works

### 1. Setup Phase

```bash
./scripts/workshop-setup.sh
```

This script:
- Clones agnosticd-v2 repository
- Creates secrets directory structure
- Provides guidance on configuring secrets

### 2. Deploy Phase

```bash
./scripts/deploy-sno.sh student1 sandbox1234
```

This script:
- Reads configuration from agnosticd-v2-vars/
- Reads secrets from agnosticd-v2-secrets/
- Calls AgnosticD v2 to provision the cluster
- Saves output to agnosticd-v2-output/

### 3. What Gets Deployed

- **Bastion**: t3a.medium instance with SSH access
- **SNO Node**: m5.4xlarge Single Node OpenShift
- **Workloads**: Cert Manager, OpenShift Virtualization, Showroom

## Customization

### Change Instance Type

Edit `agnosticd-v2-vars/low-latency-sno-aws.yml`:

```yaml
control_plane_instance_type: m5.8xlarge  # For larger workloads
```

### Change OpenShift Version

```yaml
openshift_release: "4.21"  # Or other available version
```

### Add/Remove Workloads

```yaml
workloads:
  - name: ocp4_workload_cert_manager_operator
  - name: ocp4_workload_openshift_virtualization
  # Add more workloads here
```

## Output Files

After deployment, find outputs at:

```
~/Development/agnosticd-v2-output/studentX/
├── openshift-cluster_studentX_kubeconfig           # Cluster access
├── openshift-cluster_studentX_kubeadmin-password   # Admin password
└── provision-user-info.yaml                        # Connection info
```

## Best Practices

1. **Pull Secret**: Always use inline content in secrets file
2. **Testing**: Test with one cluster before deploying multiple
3. **Cleanup**: Use destroy-sno.sh to properly clean up resources
4. **Secrets**: Never commit secrets files to git

## Troubleshooting

### Deployment Fails

```bash
# Check logs
ls -la ~/Development/agnosticd-v2-output/studentX/

# Verify secrets
cat ~/Development/agnosticd-v2-secrets/secrets.yml
cat ~/Development/agnosticd-v2-secrets/secrets-sandbox1234.yml
```

### Missing Variables

Ensure all required variables are set:
- `_guid` (passed by deploy script)
- `ocp4_pull_secret` (in secrets.yml)
- `aws_access_key_id` and `aws_secret_access_key` (in secrets-sandboxXXX.yml)

## References

- AgnosticD v2 Repository: https://github.com/agnosticd/agnosticd-v2
- Workshop Setup Guide: [../WORKSHOP_SETUP.md](../WORKSHOP_SETUP.md)
