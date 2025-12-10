# Low-Latency Workshop Deployment Documentation

This directory contains step-by-step deployment documentation for the Low-Latency Performance Workshop using AgnosticD with ansible-navigator.

## Documentation Structure

Read these documents in order:

1. **[01-PREREQUISITES.md](01-PREREQUISITES.md)** - Requirements and pre-deployment checks
2. **[02-ANSIBLE_NAVIGATOR_SETUP.md](02-ANSIBLE_NAVIGATOR_SETUP.md)** - Setting up ansible-navigator with execution environments
3. **[03-AWS_CREDENTIALS.md](03-AWS_CREDENTIALS.md)** - Configuring AWS access and OpenShift pull secrets **(UPDATED: inline content!)**
4. **[04-CONFIG_STRUCTURE.md](04-CONFIG_STRUCTURE.md)** - **NEW!** How our AgnosticD config works (extends ocp4-cluster, RHACM integration)

## Quick Start

If you're familiar with AgnosticD and ansible-navigator:

```bash
# 1. Setup
cd /home/lab-user/low-latency-performance-workshop
./workshop-scripts/01-setup-ansible-navigator.sh

# 2. Configure AWS
./workshop-scripts/02-configure-aws-credentials.sh

# 3. Test single SNO
./workshop-scripts/03-test-single-sno.sh student1          # RHPDS mode (default)
./workshop-scripts/03-test-single-sno.sh student1 rhpds     # RHPDS mode (explicit)
./workshop-scripts/03-test-single-sno.sh student1 standalone # Standalone mode

# 4. Provision all students (RHPDS workshop)
./workshop-scripts/04-provision-student-clusters.sh 30
```

### Deployment Modes

**RHPDS Mode** (default):
- Deploys SNO cluster on AWS
- Auto-imports to RHACM on hub cluster
- Requires: Hub cluster login (`oc login`)
- Use for: Workshop delivery from RHPDS

**Standalone Mode**:
- Deploys SNO cluster on AWS
- No hub integration
- Use for: Individual testing, non-RHPDS deployments

## Current Deployment Status

**Hub Cluster**: cluster-d6zdt.dynamic.redhatworkshops.io
- OpenShift: 4.20.0
- RHACM: 2.14.1
- Existing users: user1

**Target**: Deploy 30 student SNO clusters via AgnosticD

## Support

For issues, see [06-TROUBLESHOOTING.md](06-TROUBLESHOOTING.md) or check the workshop-scripts README.

