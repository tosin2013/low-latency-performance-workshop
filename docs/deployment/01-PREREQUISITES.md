# Prerequisites for Low-Latency Workshop Deployment

## Current Environment

**Hub Cluster** (from RHPDS "ACM for Kubernetes Demo (CNV Pools)"):
- URL: `https://api.cluster-d6zdt.dynamic.redhatworkshops.io:6443`
- OpenShift Version: 4.20.0
- RHACM Version: 2.14.1
- Existing Users: user1
- Domain: `*.dynamic.redhatworkshops.io`

## Required Access

### ✅ Already Available
- [x] RHPDS account with "ACM for Kubernetes Demo (CNV Pools)" access
- [x] Hub cluster with RHACM 2.14+ installed
- [x] SSH access to hub bastion
- [x] oc CLI tools on bastion

### ⚠️ Need to Obtain
- [ ] AWS account with EC2 provisioning access
- [ ] AWS access key ID and secret access key
- [ ] Red Hat account for OpenShift pull secret
- [ ] OpenShift pull secret from console.redhat.com

## AWS Requirements

### Service Quotas Needed

For 30 students, you need:
- **Running On-Demand Standard instances**: 480+ vCPUs (30 × 16 vCPU)
- **VPCs**: 30+
- **Elastic IPs**: 30+
- **EBS volumes**: 30+ (gp3, 200GB each)

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
  --region us-east-1
```

### Request Quota Increases (if needed)

```bash
# Request increase to 512 vCPUs (allows 32 × m5.4xlarge instances)
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 512 \
  --region us-east-1
```

**Note**: Quota increase requests can take 24-48 hours.

### Cost Estimate

**Per-student SNO cluster**:
- Instance: m5.4xlarge (16 vCPU, 64GB RAM)
- Storage: 200GB gp3 EBS
- Cost: ~$60/day per student

**30 students for 3-day workshop**:
- SNO clusters: ~$5,400
- Hub cluster: Included with RHPDS
- **Total**: ~$5,400

## Tools Required on Hub Bastion

### Check What's Already Installed

```bash
# On hub bastion
oc version          # Should show 4.20+
python3 --version   # Should show 3.9+
git --version       # Should be available
podman --version    # Should be available (RHEL 9)
```

### Will Install During Setup

- ansible-navigator (via pip3)
- AWS CLI (via pip3, if needed)

## Verify Hub Cluster Status

```bash
# Login to hub
oc login https://api.cluster-d6zdt.dynamic.redhatworkshops.io:6443

# Check RHACM
oc get multiclusterhub -n open-cluster-management
# Should show: multiclusterhub   Running

# Check OpenShift GitOps (optional but useful)
oc get argocd -n openshift-gitops

# Check existing user
oc get user user1
# Should exist from RHPDS provisioning

# Check you can create ManagedClusterSet (permissions test)
oc auth can-i create managedclusterset
# Should show: yes
```

## Repository Access

### Workshop Content

```bash
# Should already be cloned (current directory)
cd /home/lab-user/low-latency-performance-workshop
git remote -v
# Should show: https://github.com/tosin2013/low-latency-performance-workshop.git
```

### AgnosticD

```bash
# Should already be cloned
cd /home/lab-user/agnosticd
git remote -v
# Should show: https://github.com/tosin2013/agnosticd.git
```

## Pre-Deployment Checklist

Before proceeding to deployment:

- [ ] Hub cluster accessible via oc CLI
- [ ] RHACM showing as "Running"
- [ ] user1 exists and can login
- [ ] AWS account ready with quotas checked
- [ ] Pull secret downloaded from console.redhat.com
- [ ] Both repositories (workshop + agnosticd) cloned
- [ ] Bastion has podman and python3

## Next Steps

Once all prerequisites are met, proceed to:
→ [02-ANSIBLE_NAVIGATOR_SETUP.md](02-ANSIBLE_NAVIGATOR_SETUP.md)

## Troubleshooting Prerequisites

### Cannot login to hub cluster

```bash
# Verify hub is accessible
curl -k https://api.cluster-d6zdt.dynamic.redhatworkshops.io:6443/healthz

# Check kubeconfig
cat ~/.kube/config
```

### RHACM not showing as Running

```bash
# Check RHACM pods
oc get pods -n open-cluster-management

# Check MultiClusterHub status
oc get multiclusterhub -n open-cluster-management -o yaml
```

### AWS quota limits too low

Contact AWS support or use AWS console → Service Quotas → Request quota increase

