# AgnosticD V2 Configuration Files

This directory contains AgnosticD V2 configuration files for the Low-Latency Performance Workshop.

## Configuration Files

### `low-latency-sno-aws.yml`

Single Node OpenShift (SNO) cluster configuration for AWS deployments.

**Key Features:**
- Single node cluster (1 control plane, 0 workers)
- Includes workloads: Cert Manager, OpenShift Virtualization, Showroom
- Configured for workshop documentation deployment

**Usage:**
```bash
cd ~/Development/agnosticd-v2
./bin/agd provision -g student1 -c low-latency-sno-aws -a sandbox1234
```

**Required Customizations:**
1. Update `cloud_tags.owner` with your email address
2. Add `host_ssh_authorized_keys` with your GitHub public key URL
3. Configure secrets in `../agnosticd-v2-secrets/`

## Directory Structure

These files are symlinked to `~/Development/agnosticd-v2-vars/` so that the `agd` script can find them. The symlink is created automatically by `scripts/workshop-setup.sh`.

## Adding New Configurations

To add a new workshop configuration:

1. Create a new `.yml` file in this directory
2. Follow the structure of `low-latency-sno-aws.yml`
3. Update this README with the new configuration details

