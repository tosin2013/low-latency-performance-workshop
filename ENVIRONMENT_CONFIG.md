# Workshop Environment Configuration Reference

This document provides a quick reference for configuring the Low-Latency Performance Workshop environment.

## Quick Configuration Reference

### Current Workshop Configuration

```yaml
# From content/antora.yml
asciidoc:
  attributes:
    # Access Configuration
    ssh_user: ec2-user
    ssh_password: ""  # Key-based authentication
    ssh_command: ssh ec2-user@bastion.{guid}.dynamic.redhatworkshops.io
    
    # Cluster Access
    cluster_api: https://api.cluster-{guid}.dynamic.redhatworkshops.io:6443
    cluster_console: https://console-openshift-console.apps.cluster-{guid}.dynamic.redhatworkshops.io
```

## Environment Patterns

### Red Hat Workshops (Current)

**Infrastructure:**
- **Platform**: AWS EC2
- **Domain**: `*.dynamic.redhatworkshops.io`
- **Access**: SSH key-based authentication
- **User**: `ec2-user` (AWS standard)

**URL Patterns:**
```
Bastion Host: bastion.{guid}.dynamic.redhatworkshops.io
OpenShift API: https://api.cluster-{guid}.dynamic.redhatworkshops.io:6443
Console: https://console-openshift-console.apps.cluster-{guid}.dynamic.redhatworkshops.io
```

**Example with GUID `abc123`:**
```bash
# SSH Access
ssh ec2-user@bastion.abc123.dynamic.redhatworkshops.io

# OpenShift Login
oc login https://api.cluster-abc123.dynamic.redhatworkshops.io:6443

# Console Access
https://console-openshift-console.apps.cluster-abc123.dynamic.redhatworkshops.io
```

### Alternative Environment Configurations

#### Azure-based Workshop

```yaml
# Azure configuration example
ssh_user: azureuser
ssh_command: ssh azureuser@bastion-{guid}.eastus.cloudapp.azure.com
cluster_api: https://api.cluster-{guid}.eastus.aroapp.io:6443
cluster_console: https://console-openshift-console.apps.cluster-{guid}.eastus.aroapp.io
```

#### On-Premises Workshop

```yaml
# On-premises configuration example
ssh_user: admin
ssh_command: ssh admin@bastion-{guid}.lab.example.com
cluster_api: https://api.cluster-{guid}.lab.example.com:6443
cluster_console: https://console-openshift-console.apps.cluster-{guid}.lab.example.com
```

#### Customer Environment

```yaml
# Customer-specific configuration example
ssh_user: student
ssh_password: "workshop123"  # If password auth is used
ssh_command: ssh student@workshop-{guid}.customer.com
cluster_api: https://api.ocp-{guid}.customer.com:6443
cluster_console: https://console.ocp-{guid}.customer.com
```

## Configuration Customization Guide

### Step 1: Identify Your Environment

Determine the following for your workshop environment:

1. **Cloud Provider**: AWS, Azure, GCP, VMware, Bare Metal
2. **Domain Pattern**: How are hostnames structured?
3. **Authentication**: SSH keys, passwords, or both?
4. **User Account**: What username do participants use?
5. **OpenShift Version**: 4.19, 4.18, etc.

### Step 2: Update Antora Configuration

Edit `content/antora.yml`:

```yaml
asciidoc:
  attributes:
    # Update these based on your environment
    ssh_user: YOUR_SSH_USER
    ssh_password: "YOUR_PASSWORD_OR_EMPTY"
    ssh_command: ssh YOUR_SSH_USER@YOUR_BASTION_PATTERN
    cluster_api: https://YOUR_API_PATTERN:6443
    cluster_console: https://YOUR_CONSOLE_PATTERN
    
    # Update version information
    openshift_version: YOUR_OPENSHIFT_VERSION
    product_name: OpenShift YOUR_VERSION
```

### Step 3: Test Configuration

Use the environment validation script:

```bash
#!/bin/bash
# Test your configuration

GUID="test-guid"  # Replace with actual test GUID

# Test SSH (replace with your pattern)
ssh -o ConnectTimeout=10 YOUR_SSH_USER@bastion.$GUID.YOUR_DOMAIN "echo 'SSH OK'"

# Test OpenShift API (replace with your pattern)
curl -k --connect-timeout 10 https://api.cluster-$GUID.YOUR_DOMAIN:6443/healthz

# Test console (replace with your pattern)
curl -k --connect-timeout 10 -I https://console-openshift-console.apps.cluster-$GUID.YOUR_DOMAIN
```

## Common Configuration Scenarios

### Scenario 1: Password-Based SSH

```yaml
ssh_user: student
ssh_password: "workshop123"
ssh_command: ssh student@bastion.{guid}.workshop.example.com
```

**Usage in content:**
```asciidoc
Connect to your workshop environment (password: workshop123):
[source,bash,role=execute]
----
{ssh_command}
----
```

### Scenario 2: Different OpenShift Version

```yaml
openshift_version: 4.18
product_name: OpenShift 4.18
kube_burner_version: 1.16+
```

**Update page links:**
```yaml
page-links:
  - url: https://docs.openshift.com/container-platform/4.18/scalability_and_performance/cnf-low-latency-tuning.html
    text: OpenShift 4.18 Low Latency Tuning
```

### Scenario 3: Custom Domain

```yaml
ssh_command: ssh admin@workshop-{guid}.mycompany.com
cluster_api: https://openshift-{guid}.mycompany.com:6443
cluster_console: https://console.openshift-{guid}.mycompany.com
```

### Scenario 4: Single Cluster (No GUID)

```yaml
# Remove {guid} pattern for single cluster
ssh_command: ssh student@workshop-bastion.example.com
cluster_api: https://api.workshop-cluster.example.com:6443
cluster_console: https://console-openshift-console.apps.workshop-cluster.example.com
```

## Validation Checklist

Before deploying the workshop, verify:

- [ ] SSH access works with configured credentials
- [ ] OpenShift API is accessible from bastion host
- [ ] OpenShift console loads correctly
- [ ] DNS resolution works for all configured hostnames
- [ ] Required operators are pre-installed (RHACM, GitOps, CNV, SR-IOV)
- [ ] Performance features are available (worker-rt nodes, HugePages)
- [ ] kube-burner tool is available on bastion host

## Troubleshooting Common Issues

### SSH Connection Failures

```bash
# Check DNS resolution
nslookup bastion.{guid}.dynamic.redhatworkshops.io

# Test with verbose SSH
ssh -v ec2-user@bastion.{guid}.dynamic.redhatworkshops.io

# Check SSH key
ssh-add -l
```

### OpenShift API Access Issues

```bash
# Test API connectivity
curl -k https://api.cluster-{guid}.dynamic.redhatworkshops.io:6443/healthz

# Check from bastion host
ssh ec2-user@bastion.{guid}.dynamic.redhatworkshops.io "oc cluster-info"
```

### Console Access Problems

```bash
# Test console URL
curl -k -I https://console-openshift-console.apps.cluster-{guid}.dynamic.redhatworkshops.io

# Check route configuration
oc get route -n openshift-console
```

## Environment-Specific Notes

### AWS Considerations

- Use `ec2-user` for Amazon Linux 2 instances
- Ensure security groups allow SSH (port 22) and HTTPS (port 443)
- Consider using Session Manager for additional security

### Azure Considerations

- Use `azureuser` for standard Azure VMs
- Configure Network Security Groups appropriately
- Consider Azure Bastion for secure access

### On-Premises Considerations

- Ensure proper DNS configuration
- Configure firewall rules for required ports
- Consider certificate management for HTTPS

### VMware Considerations

- Use appropriate VM templates
- Configure networking for cluster access
- Ensure sufficient resources for performance testing

---

**Last Updated**: 2025-01-06  
**For Workshop Version**: OpenShift 4.19  
**Environment**: AWS with dynamic.redhatworkshops.io
