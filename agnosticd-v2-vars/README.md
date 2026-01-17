# AgnosticD V2 Configuration Files

This directory contains AgnosticD V2 configuration files for the Low-Latency Performance Workshop.

## Hub + Spoke Architecture

The workshop uses a **Hub + Spoke architecture** to ensure workshop documentation remains available during student cluster reboots:

- **Hub Cluster** (`workshop-hub-aws.yml`): Standard OpenShift cluster hosting Showroom (workshop docs) for all students
- **Student SNO Clusters** (`low-latency-sno-aws.yml`): Individual Single Node OpenShift clusters for hands-on performance tuning

### Why Hub + Spoke?

When students apply Performance Profiles in Module 4, their SNO cluster reboots. If Showroom runs on the same cluster, students lose access to instructions during the reboot. The Hub + Spoke architecture solves this by:

1. **Hub cluster** remains stable and never reboots (hosts docs)
2. **Student SNO clusters** can reboot safely during Module 4 (hands-on work)
3. Students always have access to workshop documentation

## Configuration Files

### `workshop-hub-aws.yml`

Standard OpenShift cluster configuration for hosting workshop documentation (Hub cluster).

**Key Features:**
- Standard OpenShift deployment (3 control plane nodes + 2 worker nodes)
- Instance types: m5.xlarge (masters), m5.large (workers)
- Workloads: Cert Manager, Showroom
- **Let's Encrypt SSL certificates** enabled for secure HTTPS access
- Hosts workshop documentation for ALL students

**Deployment Order:** Deploy **SECOND** (after student SNO clusters)

**Usage:**
```bash
cd ~/Development/agnosticd-v2

# Step 1: Deploy student SNO clusters FIRST (see below)
# Step 2: Deploy hub cluster (no extra vars needed)
# Step 3: Configure per-student Showroom instances using deploy-student-showrooms.sh

# Deploy Hub cluster (no credentials needed - Showroom configured later)
./bin/agd provision -g hub -c workshop-hub-aws -a sandbox1111

# After Hub deployment, configure per-student Showrooms:
cd ~/low-latency-performance-workshop
./scripts/deploy-student-showrooms.sh --students student1,student2
```

### `low-latency-sno-aws.yml`

Single Node OpenShift (SNO) cluster configuration for individual students (Spoke clusters).

**Key Features:**
- Single node cluster (1 control plane, 0 workers)
- Instance type: m5.4xlarge (default, virtualized - cost-effective)
- Workloads: Cert Manager, OpenShift Virtualization
- **Let's Encrypt SSL certificates** enabled for secure HTTPS access
- **Showroom is NOT deployed** (hosted on Hub cluster)
- Students access this cluster via bastion for hands-on work

**Deployment Order:** Deploy **FIRST** (before Hub cluster)

**Usage:**
```bash
cd ~/Development/agnosticd-v2

# Deploy student SNO clusters FIRST (one per student)
./bin/agd provision -g student1 -c low-latency-sno-aws -a sandbox2222
./bin/agd provision -g student2 -c low-latency-sno-aws -a sandbox2222
./bin/agd provision -g student3 -c low-latency-sno-aws -a sandbox2222

# After deployment, extract credentials from:
# ~/Development/agnosticd-v2-output/studentX/provision-user-info.yaml
```

#### Instance Type Selection

The default configuration uses `m5.4xlarge` (virtualized instance), which is cost-effective and supports most workshop exercises:

- **Cost**: ~$0.77/hour (us-east-2)
- **Supports**: CPU isolation, HugePages, NUMA tuning (Module 4)
- **RT Kernel**: Disabled by default (works on virtualized instances)
- **Recommended for**: Most workshops where cost is a consideration

**Bare-Metal Instances (for RT Kernel Support):**

If you need Real-Time (RT) kernel support in Module 4, you can uncomment a metal instance type in `low-latency-sno-aws.yml`. Metal instances are required for RT kernel but are ~5x more expensive:

| Instance Type | vCPUs | RAM | Cost/hr (us-east-2) | Best For |
|---------------|-------|-----|---------------------|----------|
| **m5zn.metal** (recommended) | 48 | 192 GiB | ~$3.96 | Best latency, smallest metal |
| c5.metal | 96 | 192 GiB | ~$4.08 | CPU-intensive workloads |
| c5n.metal | 72 | 192 GiB | ~$3.89 | Network-intensive workloads |
| m5.metal | 96 | 384 GiB | ~$4.61 | Balanced workloads, more memory |
| c7i.metal-24xl | 96 | 192 GiB | ~$4.28 | Latest generation performance |

**To use a metal instance:**

1. Edit `low-latency-sno-aws.yml`
2. Comment out the default `control_plane_instance_type: m5.4xlarge`
3. Uncomment your preferred metal instance type
4. Deploy as normal

**Note:** Pricing is approximate and may vary by region. Check current pricing at [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/).

### `low-latency-sno-dev.yml`

Development/Test SNO cluster configuration for validating workshop functionality before deploying to production/student environments.

**Key Features:**
- Single node cluster (1 control plane, 0 workers)
- Easy instance type toggle (virtualized vs bare-metal)
- Automated post-deployment validation
- Test VM creation to verify OpenShift Virtualization
- Clear feedback on emulation requirements

**Instance Type Options:**

| Instance Type | KVM Mode | Emulation | Cost/hr (us-east-2) | Use Case |
|---------------|----------|-----------|---------------------|----------|
| **m5.4xlarge** (default) | Software emulation | Required | ~$0.77 | Test virtualized setup |
| **m5zn.metal** (bare-metal default) | Native hardware KVM | Not needed | ~$3.96 | Test bare-metal setup |

**Bare-Metal Instance Selection:**

When using the `baremetal` parameter, the dev config uses **m5zn.metal** by default. This is the recommended bare-metal instance for testing:
- 48 vCPUs, 192 GiB RAM
- Best latency, smallest metal instance
- Cost: ~$3.96/hour (us-east-2)

**Alternative Bare-Metal Options:**

The config file also includes commented alternatives that you can uncomment if needed:

| Instance Type | vCPUs | RAM | Cost/hr (us-east-2) | Best For |
|---------------|-------|-----|---------------------|----------|
| **m5zn.metal** (default) | 48 | 192 GiB | ~$3.96 | Best latency, smallest metal |
| c5.metal | 96 | 192 GiB | ~$4.08 | CPU-intensive workloads |
| c5n.metal | 72 | 192 GiB | ~$3.89 | Network-intensive workloads |
| m5.metal | 96 | 384 GiB | ~$4.61 | Balanced workloads, more memory |
| c7i.metal-24xl | 96 | 192 GiB | ~$4.28 | Latest generation performance |

To use an alternative bare-metal instance, edit `low-latency-sno-dev.yml` and uncomment the desired instance type.

**Deployment Order:** Can be deployed independently for testing

**Usage:**
```bash
# Deploy dev SNO with m5.4xlarge (virtualized, needs emulation)
cd ~/low-latency-performance-workshop
./scripts/deploy-sno-dev.sh dev1 sandbox3576 virtualized

# Deploy dev SNO with bare-metal (m5zn.metal, native KVM, no emulation)
./scripts/deploy-sno-dev.sh dev1 sandbox3576 baremetal

# Or use AgnosticD directly:
cd ~/Development/agnosticd-v2
./bin/agd provision -g dev1 -c low-latency-sno-dev -a sandbox3576
```

**Post-Deployment Validation:**

After deployment, the validation script automatically runs checks to verify:
- ✅ OpenShift Virtualization operator is running
- ✅ KVM emulation is correctly configured (for virtualized instances)
- ✅ Test VM can be created and boots successfully
- ✅ Cert Manager operator is working
- ✅ Node health is good

**Manual Validation:**
```bash
# Run validation manually
export KUBECONFIG=~/Development/agnosticd-v2-output/dev1/openshift-cluster_dev1_kubeconfig
./scripts/validate-sno-dev.sh dev1 virtualized

# Check validation results
oc get configmap sno-validation-results -n default -o yaml
```

**When to Use Dev Config:**

- **Before student deployments**: Validate that all workshop features work correctly
- **Testing instance types**: Verify m5.4xlarge emulation vs bare-metal native KVM
- **Troubleshooting**: Isolate issues with OpenShift Virtualization or other operators
- **Development**: Test configuration changes before applying to production

**Differences from Production Config:**

| Feature | Production (`low-latency-sno-aws.yml`) | Dev (`low-latency-sno-dev.yml`) |
|---------|--------------------------------------|--------------------------------|
| Purpose | Student deployments | Development/testing |
| Instance toggle | Manual edit required | Command-line parameter |
| Validation | Manual | Automated post-deploy |
| Test VM | Not created | Created and verified |
| Emulation check | Manual | Automated |

## Deployment Workflow

### Step 1: Deploy Student SNO Clusters (AWS Environment 2)

Deploy all student SNO clusters first. Each deployment generates:
- Bastion hostname (e.g., `bastion.student1.sandbox2222.opentlc.com`)
- Bastion password
- Console URL

```bash
# Deploy to AWS Environment 2 (student sandbox)
./bin/agd provision -g student1 -c low-latency-sno-aws -a sandbox2222
./bin/agd provision -g student2 -c low-latency-sno-aws -a sandbox2222
```

### Step 2: Deploy Hub Cluster (AWS Environment 1)

Deploy the Hub cluster (no student credentials needed):

```bash
# Deploy to AWS Environment 1 (hub sandbox)
./bin/agd provision -g hub -c workshop-hub-aws -a sandbox1111
```

### Step 3: Configure Per-Student Showroom Instances

After the Hub cluster is deployed, configure per-student Showroom instances:

```bash
cd ~/low-latency-performance-workshop
./scripts/deploy-student-showrooms.sh --students student1,student2
```

This script reads student credentials from `~/Development/agnosticd-v2-output/` and creates per-student Showroom instances with wetty terminals connected to each student's bastion.

## AWS Resource Requirements

### VPC Limit Requirements

Each OpenShift cluster creates its own VPC. AWS accounts have a **default limit of 5 VPCs per region**, which is quickly exceeded when deploying multiple clusters.

#### VPC Usage Per Cluster

| Cluster Type | VPCs Created |
|--------------|--------------|
| Hub Cluster | 2 VPCs (1 for bastion, 1 for OpenShift) |
| Student SNO | 2 VPCs (1 for bastion, 1 for OpenShift) |

#### VPC Requirements by Student Count

| Students | Hub VPCs | Student VPCs | Total VPCs | Recommended Limit |
|----------|----------|--------------|------------|-------------------|
| 1 | 2 | 2 | 4 | 10 |
| 2 | 2 | 4 | 6 | 10 |
| 3 | 2 | 6 | 8 | 15 |
| 5 | 2 | 10 | 12 | 20 |
| 10 | 2 | 20 | 22 | 30 |
| 15 | 2 | 30 | 32 | 40 |
| 20 | 2 | 40 | 42 | 50 |

**Formula:** `Total VPCs = 2 (Hub) + (Number of Students × 2)`

#### Requesting VPC Limit Increase

```bash
# Check current limit
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --region us-east-2 \
  --query 'Quota.Value' \
  --output text

# Request increase (recommended: 50 for up to 20 students)
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 50 \
  --region us-east-2

# Check request status
aws service-quotas list-requested-service-quota-change-history \
  --service-code vpc \
  --region us-east-2 \
  --query 'RequestedQuotas[?QuotaCode==`L-F678F1CE`] | [0].{Status:Status,DesiredValue:DesiredValue}' \
  --output table
```

**Note:** VPC quota increases are usually approved automatically within minutes for reasonable requests.

### Elastic IP (EIP) Requirements

Each OpenShift cluster requires Elastic IPs for NAT Gateways (one per availability zone). This is a critical constraint that must be addressed before deployment.

#### EIP Usage Per Cluster

| Cluster Type | NAT Gateways | Elastic IPs Required |
|--------------|--------------|---------------------|
| Hub Cluster | 3 (one per AZ) | 3 EIPs |
| Student SNO | 2-3 (one per AZ) | 2-3 EIPs (use 3 for planning) |

#### EIP Requirements by Student Count

| Students | Hub EIPs | Student EIPs | Total EIPs | Recommended Limit |
|----------|----------|--------------|------------|-------------------|
| 1 | 3 | 3 | 6 | 10 |
| 3 | 3 | 9 | 12 | 20 |
| 5 | 3 | 15 | 18 | 25 |
| 10 | 3 | 30 | 33 | 40 |
| 15 | 3 | 45 | 48 | 55 |
| 20 | 3 | 60 | 63 | 70 |

**Formula:** `Total EIPs = 3 (Hub) + (Number of Students × 3)`

#### Requesting EIP Limit Increase

AWS accounts typically start with a limit of **5 Elastic IPs**, which is insufficient for the workshop. You must request an increase:

```bash
# Check current limit
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --query 'Quota.Value' \
  --output text

# Request increase (recommended: 70 for up to 20 students)
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --desired-value 70

# Check request status
aws service-quotas list-requested-service-quota-change-history \
  --service-code ec2 \
  --query 'RequestedQuotas[?QuotaCode==`L-0263D0A3`] | [0].{Status:Status,DesiredValue:DesiredValue}' \
  --output table
```

**Note:** Quota increases are usually approved automatically within minutes for reasonable requests.

#### Alternative: Two AWS Environments

If you cannot increase the EIP limit, deploy Hub and Students in separate AWS accounts:
- Hub cluster in Account 1 (3 EIPs)
- Student clusters in Account 2 (2-3 EIPs each)

### EC2 vCPU Requirements

| Cluster Type | Instances | Total vCPUs |
|--------------|-----------|-------------|
| Hub Cluster | 3x m5.xlarge + 2x m5.large + 1x bastion | 18 vCPUs |
| Student SNO | 1x m5.4xlarge + 1x bastion | 18 vCPUs |

**Example:** 1 Hub + 20 Students = 378 vCPUs (well within typical AWS limits of 1152+ vCPUs)

## SSL Certificate Configuration

Both configurations use **Let's Encrypt SSL certificates** for secure HTTPS access.

### Requirements

1. **AWS Credentials with Route53 Permissions:**
   - `route53:GetChange`
   - `route53:ChangeResourceRecordSets`
   - `route53:ListHostedZones`

2. **AWS Credentials in Secrets:**
   ```yaml
   # In ~/Development/agnosticd-v2-secrets/secrets-sandboxXXX.yml
   aws_access_key_id: AKIAXXXXXXXXXXXXXXXX
   aws_secret_access_key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. **Let's Encrypt Email (Required):**
   Let's Encrypt requires an email address for account registration and notifications.
   Set this when deploying:
   ```bash
   ./bin/agd provision -g student1 -c low-latency-sno-aws -a sandbox5466 \
     -e "ocp4_workload_cert_manager_email=your-email@example.com"
   ```
   Or add to your secrets file:
   ```yaml
   ocp4_workload_cert_manager_email: your-email@example.com
   ```

4. **Cert Manager Provider:**
   ```yaml
   ocp4_workload_cert_manager_provider: letsencrypt
   ocp4_workload_cert_manager_email: "{{ ocp4_workload_cert_manager_email | default('admin@example.com') }}"
   ocp4_workload_cert_manager_install_ingress_certificates: true
   # For SNO clusters: API certificates disabled to avoid deployment timing issues
   # For Hub clusters: API certificates enabled (deployed later, more time for certs)
   ocp4_workload_cert_manager_install_api_certificates: false  # SNO: false, Hub: true
   ```

### SSL Certificate Features

- **Automatic certificate provisioning** via DNS-01 challenge
- **Ingress certificates**: Enabled for both SNO and Hub clusters (Let's Encrypt)
  - Provides secure HTTPS for OpenShift Console and applications
- **API certificates**: 
  - **SNO clusters**: Disabled (`false`) to avoid SSL verification timing issues during deployment
    - API uses default self-signed certificate (still secure, just not Let's Encrypt)
    - AgnosticD connects to API before Let's Encrypt certificates are ready
  - **Hub clusters**: Enabled (`true`) - deployed later, more time for certificates to be ready
- **Secure HTTPS** for OpenShift Console and API
- **Secure HTTPS** for Showroom documentation
- **Automatic renewal** handled by Cert Manager

## Required Customizations

Before deploying, update both configuration files:

1. **Update `cloud_tags.owner`** with your email address
2. **Add `host_ssh_authorized_keys`** with your GitHub public key URL (optional)
3. **Configure secrets** in `~/Development/agnosticd-v2-secrets/`:
   - `secrets.yml` - OpenShift pull secret
   - `secrets-sandboxXXX.yml` - AWS credentials with Route53 permissions

## Directory Structure

These files are symlinked to `~/Development/agnosticd-v2-vars/` so that the `agd` script can find them. The symlink is created automatically by `scripts/workshop-setup.sh`.

## Helper Script

For automated deployment, use the helper script:

```bash
./scripts/deploy-workshop.sh \
  --hub-account sandbox1111 \
  --student-account sandbox2222 \
  --students student1,student2,student3
```

This script:
1. Deploys all student SNOs first
2. Collects credentials automatically
3. Deploys Hub cluster with collected credentials
4. Outputs consolidated access information

## Quota Increase Request Status

Track the status of your AWS quota increase requests:

```bash
# Check VPC limit request status
aws service-quotas list-requested-service-quota-change-history \
  --service-code vpc \
  --region us-east-2 \
  --query 'RequestedQuotas[?QuotaCode==`L-F678F1CE`] | [0].{Status:Status,DesiredValue:DesiredValue}' \
  --output table

# Check EIP limit request status
aws service-quotas list-requested-service-quota-change-history \
  --service-code ec2 \
  --region us-east-2 \
  --query 'RequestedQuotas[?QuotaCode==`L-0263D0A3`] | [0].{Status:Status,DesiredValue:DesiredValue}' \
  --output table
```| Quota | Service Code | Quota Code | Default | Recommended |
|-------|--------------|------------|---------|-------------|
| VPCs per Region | vpc | L-F678F1CE | 5 | 50 |
| Elastic IPs per Region | ec2 | L-0263D0A3 | 5 | 70 |