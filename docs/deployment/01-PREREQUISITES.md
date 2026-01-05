# Prerequisites for Low-Latency Workshop Deployment

## Required Access

### ✅ What You Need
- [ ] AWS account with EC2 provisioning access (or AWS Sandbox from demo.redhat.com)
- [ ] AWS access key ID and secret access key
- [ ] Red Hat account for OpenShift pull secret
- [ ] OpenShift pull secret from console.redhat.com

## AWS Requirements

### Service Quotas Needed

For each SNO cluster, you need:
- **Running On-Demand Standard instances**: 16+ vCPUs (1 × m5.4xlarge)
- **VPCs**: 1+
- **Elastic IPs**: 2+
- **EBS volumes**: 2+ (gp3, 200GB each)

### Check Current Quotas

```bash
# Install AWS CLI if not present
pip3 install --user awscli
export PATH=$PATH:~/.local/bin

# Configure AWS credentials (temporarily for quota check)
aws configure

# Check EC2 instance quota
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-2
```

### Request Quota Increases (if needed)

```bash
# Request increase to 64 vCPUs (allows 4 × m5.4xlarge instances)
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 64 \
  --region us-east-2
```

**Note**: Quota increase requests can take 24-48 hours.

### Cost Estimate

**Per SNO cluster**:
- Instance: m5.4xlarge (16 vCPU, 64GB RAM)
- Bastion: t3a.medium (2 vCPU, 4GB RAM)
- Storage: 200GB gp3 EBS
- Cost: ~$20/day per cluster

## Tools Required

### On Your Workstation

```bash
# Check what's installed
python3 --version   # Should show 3.9+
git --version       # Should be available
```

### Will Install During Setup

- ansible-navigator (via pip3)
- AWS CLI (via pip3, if needed)
- AgnosticD v2

## Repository Access

### Workshop Content

```bash
# Clone if not already done
cd ~/Development
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
```

### AgnosticD v2

The setup script will clone this automatically:
```bash
# Or clone manually
cd ~/Development
git clone https://github.com/agnosticd/agnosticd-v2.git
```

## Pre-Deployment Checklist

Before proceeding to deployment:

- [ ] AWS account ready with quotas checked
- [ ] Pull secret downloaded from console.redhat.com
- [ ] Workshop repository cloned
- [ ] Python3 available

## Next Steps

Once all prerequisites are met, proceed to:
→ [02-ANSIBLE_NAVIGATOR_SETUP.md](02-ANSIBLE_NAVIGATOR_SETUP.md)

## Troubleshooting Prerequisites

### AWS quota limits too low

Contact AWS support or use AWS console → Service Quotas → Request quota increase

### Pull secret issues

1. Go to https://console.redhat.com/openshift/install/pull-secret
2. Click "Download pull secret"
3. Save as `~/Development/agnosticd-v2-secrets/pull-secret.json`
