# Low-Latency Performance Workshop - Deployment Setup Guide

This guide explains how to set up and deploy the Low-Latency Performance Workshop using AgnosticD V2.

## Quick Start (5 minutes)

The fastest way to get started is using the automated setup script:

```bash
cd ~/Development/low-latency-performance-workshop
./scripts/workshop-setup.sh
```

This script will:
- Check prerequisites (OS, podman, python3.12+)
- Clone required repositories
- Create directory structure
- Set up configuration symlinks
- Generate secrets templates
- Run AgnosticD V2 setup

After running the setup script, you'll need to:
1. Configure your secrets files (AWS credentials, OpenShift pull secret)
2. Customize the deployment configuration
3. Deploy your first cluster

## Prerequisites

### Supported Operating Systems

- **RHEL 9.5+** or **RHEL 10.0+**
- **Fedora 41+**
- **macOS Sequoia+**

### Required Software

- **podman** - Container runtime
- **python3.12+** - Python interpreter
- **git** - Version control

### Installation by OS

#### RHEL 9.5/9.6

```bash
# Enable CodeReady Builder repository
sudo subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms

# Install prerequisites
sudo dnf -y install git python3.12 python3.12-devel gcc oniguruma-devel podman

# Set Python 3.12 as default (if needed)
sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 120
sudo alternatives --config python3
```

#### RHEL 10.0

```bash
# Enable CodeReady Builder repository
sudo subscription-manager repos --enable codeready-builder-for-rhel-10-$(arch)-rpms

# Install prerequisites
sudo dnf -y install git python3 python3-devel gcc oniguruma-devel podman
```

#### Fedora 41+

```bash
sudo dnf -y install podman git python3 python3-devel pip3 gcc oniguruma-devel
```

#### macOS

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install prerequisites
brew install python@3.13 podman
```

## Manual Setup

If you prefer to set up manually or the automated script doesn't work for your environment:

### 1. Clone Repositories

```bash
mkdir -p ~/Development
cd ~/Development

# Clone AgnosticD V2
git clone https://github.com/agnosticd/agnosticd-v2.git

# Clone workshop repository (if not already done)
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
```

### 2. Create Directory Structure

```bash
mkdir -p ~/Development/agnosticd-v2-secrets
mkdir -p ~/Development/agnosticd-v2-output
```

### 3. Set Up Configuration Symlink

```bash
# Create symlink from workshop vars to expected location
ln -sf ~/Development/low-latency-performance-workshop/agnosticd-v2-vars \
       ~/Development/agnosticd-v2-vars
```

### 4. Run AgnosticD Setup

```bash
cd ~/Development/agnosticd-v2
./bin/agd setup
```

### 5. Configure Secrets

#### General Secrets (`~/Development/agnosticd-v2-secrets/secrets.yml`)

Edit the file and add:

```yaml
---
# OpenShift Pull Secret (required)
ocp4_pull_secret: '<Your pull secret from console.redhat.com>'

# Either Satellite OR RHN credentials (for bastion packages)
# Option 1: Satellite
host_satellite_repositories_hostname: satellite.example.com
host_satellite_repositories_org: YourOrg
host_satellite_repositories_activationkey: your-activation-key

# Option 2: RHN (uncomment if using RHN)
# host_rhn_repositories_username: your-rhn-username
# host_rhn_repositories_password: your-rhn-password
```

**Getting your OpenShift pull secret:**
1. Visit https://console.redhat.com/openshift/create/local
2. Download or copy your pull secret JSON
3. Paste it into `secrets.yml` (keep the quotes)

#### AWS Account Secrets (`~/Development/agnosticd-v2-secrets/secrets-sandboxXXX.yml`)

Create a file named `secrets-sandbox1234.yml` (replace `1234` with your sandbox number):

```yaml
---
# AWS credentials from Red Hat Demo Platform
aws_access_key_id: YOUR_ACCESS_KEY_ID
aws_secret_access_key: YOUR_SECRET_ACCESS_KEY

# Replace 1234 with your sandbox number
base_domain: sandbox1234.opentlc.com

# Disable capacity reservations for local development
agnosticd_aws_capacity_reservation_enable: false
```

**Getting AWS credentials:**
1. Visit https://demo.redhat.com
2. Request an "AWS Blank Open Environment"
3. Copy the access key ID and secret access key
4. Note your sandbox number (in the domain name)

### 6. Customize Deployment Configuration

Edit `~/Development/low-latency-performance-workshop/agnosticd-v2-vars/low-latency-sno-aws.yml`:

**Required changes:**
1. Update `cloud_tags.owner` with your email address
2. Add `host_ssh_authorized_keys` with your GitHub public key:

```yaml
cloud_tags:
  - owner: your.email@example.com  # ← Update this

host_ssh_authorized_keys:
  - key: https://github.com/YOUR_GITHUB_USERNAME.keys  # ← Add this
```

## Deployment Commands

### Deploy a Single SNO Cluster

```bash
cd ~/Development/low-latency-performance-workshop
./scripts/deploy-sno.sh student1 sandbox1234
```

Or use the `agd` command directly:

```bash
cd ~/Development/agnosticd-v2
./bin/agd provision \
  --guid student1 \
  --config low-latency-sno-aws \
  --account sandbox1234
```

### Check Cluster Status

```bash
./scripts/status-sno.sh student1 sandbox1234
```

### Destroy a Cluster

```bash
./scripts/destroy-sno.sh student1 sandbox1234
```

## What Gets Deployed

When you deploy a cluster, AgnosticD V2 will:

1. **Provision Infrastructure**
   - Create VPC and networking
   - Launch bastion host (t3a.medium)
   - Launch SNO node (m5.4xlarge)

2. **Install OpenShift**
   - Deploy OpenShift 4.20 on the SNO node
   - Configure cluster networking
   - Set up authentication

3. **Deploy Workloads**
   - **Cert Manager** - Certificate management
   - **OpenShift Virtualization** - VM workloads
   - **Showroom** - Workshop documentation UI

## Accessing Your Cluster

After deployment completes, you'll find:

### Cluster Credentials

- **Kubeconfig**: `~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig`
- **Password**: `~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeadmin-password`

### Cluster URLs

Check the output directory for `provision-user-info.yaml` which contains:
- OpenShift Console URL
- OpenShift API URL
- Workshop documentation URL
- Bastion SSH access information

### Example Access

```bash
# Export kubeconfig
export KUBECONFIG=~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeconfig

# Login
oc login -u kubeadmin -p $(cat ~/Development/agnosticd-v2-output/student1/openshift-cluster_student1_kubeadmin-password)

# Check cluster
oc get nodes
oc get clusterversion
```

## Troubleshooting

### Setup Script Fails

**Issue**: Prerequisites not met
- **Solution**: Install missing software (podman, python3.12+, git)
- Check OS compatibility

**Issue**: Symlink creation fails
- **Solution**: Remove existing `~/Development/agnosticd-v2-vars` directory or symlink first

### Deployment Fails

**Issue**: AWS credentials invalid
- **Solution**: Verify credentials in `secrets-sandboxXXX.yml`
- Check that sandbox number matches the domain

**Issue**: OpenShift pull secret invalid
- **Solution**: Get a fresh pull secret from console.redhat.com
- Ensure JSON is properly quoted in `secrets.yml`

**Issue**: SSH key not found
- **Solution**: Verify GitHub username is correct
- Test: `curl https://github.com/YOUR_USERNAME.keys`

### Cluster Not Accessible

**Issue**: Can't connect to cluster
- **Solution**: Wait 5-10 minutes after deployment completes
- Check cluster status: `./scripts/status-sno.sh student1 sandbox1234`
- Verify DNS resolution for cluster domain

**Issue**: Workloads not installing
- **Solution**: Check operator subscriptions: `oc get subscriptions -A`
- Review logs: `oc logs -n <namespace> <pod-name>`

## Directory Structure

After setup, your directory structure should look like:

```
~/Development/
├── agnosticd-v2/                    # AgnosticD V2 framework
├── agnosticd-v2-vars -> low-latency-performance-workshop/agnosticd-v2-vars/  # Symlink
├── agnosticd-v2-secrets/            # Your secrets (never commit!)
│   ├── secrets.yml
│   └── secrets-sandbox1234.yml
├── agnosticd-v2-output/             # Deployment outputs
│   └── student1/
│       ├── openshift-cluster_student1_kubeconfig
│       └── ...
└── low-latency-performance-workshop/  # Workshop repository
    ├── agnosticd-v2-vars/           # Configuration files
    │   └── low-latency-sno-aws.yml
    └── scripts/                     # Deployment scripts
        ├── workshop-setup.sh
        ├── deploy-sno.sh
        ├── destroy-sno.sh
        └── status-sno.sh
```

## Next Steps

After your first successful deployment:

1. **Explore the cluster**: Access the OpenShift console
2. **Review workloads**: Check installed operators and Showroom
3. **Access workshop docs**: Visit the Showroom URL from user-info.yaml
4. **Deploy more clusters**: Use different GUIDs for multiple students

## Additional Resources

- [AgnosticD V2 Setup Documentation](https://github.com/agnosticd/agnosticd-v2/blob/main/docs/setup.adoc)
- [Workshop Content Repository](https://github.com/tosin2013/low-latency-performance-workshop)
- [OpenShift Documentation](https://docs.openshift.com/)

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review deployment logs in `~/Development/agnosticd-v2-output/<guid>/`
3. Check AgnosticD V2 documentation
4. Open an issue in the workshop repository

