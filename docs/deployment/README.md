# Low-Latency Workshop Deployment Documentation

This directory contains step-by-step deployment documentation for the Low-Latency Performance Workshop using AgnosticD v2.

## Documentation Structure

Read these documents in order:

1. **[01-PREREQUISITES.md](01-PREREQUISITES.md)** - Requirements and pre-deployment checks
2. **[02-ANSIBLE_NAVIGATOR_SETUP.md](02-ANSIBLE_NAVIGATOR_SETUP.md)** - Setting up ansible-navigator with execution environments
3. **[03-AWS_CREDENTIALS.md](03-AWS_CREDENTIALS.md)** - Configuring AWS access and OpenShift pull secrets
4. **[04-CONFIG_STRUCTURE.md](04-CONFIG_STRUCTURE.md)** - How our AgnosticD config works

## Quick Start

If you're familiar with AgnosticD v2:

```bash
# 1. Setup
cd ~/Development/low-latency-performance-workshop
./scripts/workshop-setup.sh

# 2. Configure secrets
# Edit ~/Development/agnosticd-v2-secrets/secrets.yml
# Create ~/Development/agnosticd-v2-secrets/secrets-sandboxXXX.yml

# 3. Deploy SNO cluster
./scripts/deploy-sno.sh student1 sandbox1234

# 4. Check status
./scripts/status-sno.sh student1 sandbox1234

# 5. Destroy when done
./scripts/destroy-sno.sh student1 sandbox1234
```

## What Gets Deployed

- **Bastion**: t3a.medium instance for cluster management
- **SNO Node**: m5.4xlarge Single Node OpenShift
- **Showroom**: Workshop documentation site
- **Operators**: OpenShift Virtualization, Node Tuning

## Support

For issues, see [06-TROUBLESHOOTING.md](06-TROUBLESHOOTING.md) or check the [Workshop Setup Guide](../WORKSHOP_SETUP.md).
