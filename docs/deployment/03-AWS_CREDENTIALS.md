# AWS Credentials Configuration

## Overview

For SNO (Single Node OpenShift) provisioning, you need:
1. ✅ AWS credentials (access key + secret)
2. ✅ OpenShift pull secret

**Important**: You do **NOT** need Satellite or RHEL subscription configuration for SNO clusters. SNO uses CoreOS which handles package management internally.

## Step 1: Obtain AWS Credentials

### Option A: Your Personal AWS Account

1. Login to [AWS Console](https://console.aws.amazon.com)
2. Navigate to: IAM → Users → Your User → Security credentials
3. Click "Create access key" → Use case: "Command Line Interface (CLI)"
4. Download or copy:
   - Access key ID (starts with `AKIA...`)
   - Secret access key (shown only once!)

### Option B: AWS Sandbox from demo.redhat.com

1. Order "AWS Sandbox" from demo.redhat.com catalog
2. Receive email with:
   - AWS access key ID
   - AWS secret access key
   - AWS region
   - Sandbox ID (e.g., sandbox1234)

**Note**: Sandbox credentials have quota limits and expiration dates.

### Required IAM Permissions

Your AWS user/role needs permissions to:
- Create EC2 instances
- Create VPCs, subnets, security groups
- Create Route53 hosted zones (or use existing)
- Create EBS volumes
- Create Elastic IPs

## Step 2: Get OpenShift Pull Secret

### Why is this needed?

The pull secret authenticates to Red Hat's container registries to download OpenShift images.

### Get Your Pull Secret

```bash
# 1. Visit Red Hat Console
open https://console.redhat.com/openshift/install/pull-secret

# 2. Login with your Red Hat account credentials

# 3. Click "Download" or "Copy pull secret"

# 4. Save to file on hub bastion
cat > ~/pull-secret.json << 'EOF'
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNo...",
      "email": "your@email.com"
    },
    "quay.io": {
      "auth": "b3BlbnNo...",
      "email": "your@email.com"
    },
    "registry.connect.redhat.com": {
      "auth": "b3BlbnNo...",
      "email": "your@email.com"
    },
    "registry.redhat.io": {
      "auth": "b3BlbnNo...",
      "email": "your@email.com"
    }
  }
}
EOF

# 5. Secure the file
chmod 600 ~/pull-secret.json

# 6. Verify it's valid JSON
jq . ~/pull-secret.json
```

## Step 3: Configure AWS CLI (Optional but Recommended)

```bash
# Install AWS CLI if not present
pip3 install --user awscli
export PATH=$PATH:~/.local/bin

# Configure credentials interactively
aws configure
# Enter:
#   AWS Access Key ID: YOUR_KEY
#   AWS Secret Access Key: YOUR_SECRET
#   Default region: us-east-1
#   Default output format: json

# Test connectivity
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

## Step 4: Create AWS Credentials File

Even though `aws configure` creates credentials, we'll ensure the format is correct:

```bash
mkdir -p ~/.aws

cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
region = us-east-1
EOF

chmod 600 ~/.aws/credentials
```

## Step 5: Create AgnosticD Secrets File

**This is the key file for AgnosticD** - simplified for SNO deployment:

```bash
cat > ~/secrets-ec2.yml << 'EOF'
---
# Cloud Provider
cloud_provider: ec2

# AWS Credentials
aws_access_key_id: YOUR_ACCESS_KEY_ID
aws_secret_access_key: YOUR_SECRET_ACCESS_KEY

# AWS Region
aws_region: us-east-1

# Subdomain (demo.redhat.com pattern)
subdomain_base_suffix: ".sandboxXXX.opentlc.com"

# OpenShift Pull Secret (REQUIRED)
# Uses Jinja2 lookup to read from file
ocp4_pull_secret: '{{ lookup("file", "~/pull-secret.json") }}'

# ========================================
# NOTE: NO repo_method Configuration!
# ========================================
# SNO uses CoreOS (not RHEL), so we do NOT need:
#   - repo_method: satellite
#   - set_repositories_satellite_*
#   - rhel_subscription_user/pass
#
# CoreOS handles package management internally
# ========================================
EOF

chmod 600 ~/secrets-ec2.yml
```

### Edit the File with Your Credentials

```bash
# Replace placeholders with your actual credentials
vim ~/secrets-ec2.yml

# Or use sed
sed -i 's/YOUR_ACCESS_KEY_ID/AKIAIOSFODNN7EXAMPLE/' ~/secrets-ec2.yml
sed -i 's/YOUR_SECRET_ACCESS_KEY/wJalrXUtnFEMI\/K7MDENG\/bPxRfiCYEXAMPLEKEY/' ~/secrets-ec2.yml
```

## Step 6: Verify Configuration

```bash
# Test AWS credentials
aws ec2 describe-regions --region us-east-1

# Should list AWS regions

# Verify pull secret is valid JSON
jq . ~/pull-secret.json

# Should show parsed JSON without errors

# Check secrets file
cat ~/secrets-ec2.yml

# Should show your configuration without errors
```

## Security Best Practices

### File Permissions

```bash
# Ensure restrictive permissions
chmod 600 ~/secrets-ec2.yml
chmod 600 ~/.aws/credentials
chmod 600 ~/pull-secret.json

# Verify
ls -la ~/ | grep -E '(secrets|pull-secret|\.aws)'
```

### Git Ignore

Add to `.gitignore` to prevent accidental commits:

```bash
cat >> ~/.gitignore << 'EOF'
# Credentials and secrets
*secret*
*.secret
secrets-*
*credentials*
pull-secret*
.aws/credentials
EOF
```

### Environment Variables (Alternative Method)

If you prefer not to store credentials in files:

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="YOUR_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET"
export AWS_DEFAULT_REGION="us-east-1"

# AgnosticD will use these automatically
# However, you still need ~/pull-secret.json
```

## What About Satellite/RHN Configuration?

### Common Question: "Do I need Satellite credentials?"

**Answer**: **No, not for SNO provisioning!**

Many AgnosticD example files show Satellite configuration like:
```yaml
# YOU DO NOT NEED THIS FOR SNO!
repo_method: satellite
set_repositories_satellite_ha: true
set_repositories_satellite_url: labsat-ha.opentlc.com
set_repositories_satellite_org: Red_Hat_GPTE_Labs
set_repositories_satellite_activationkey: YOUR_KEY
```

**Why not?**
- SNO uses **CoreOS** (not RHEL)
- CoreOS is immutable and self-contained
- Package management handled by OpenShift installer
- No RHEL repos needed

### When Would You Need Satellite/RHN?

Only if your AgnosticD config provisions **RHEL-based VMs** like:
- Bastion hosts (RHEL)
- RHEL worker nodes (not CoreOS)
- Helper VMs for services

**Our config**: SNO only → **No Satellite/RHN needed**

## Verification Checklist

Before proceeding, verify:

- [ ] AWS credentials in `~/.aws/credentials`
- [ ] Pull secret saved to `~/pull-secret.json`
- [ ] Secrets file created at `~/secrets-ec2.yml`
- [ ] All credential files have `600` permissions
- [ ] `aws sts get-caller-identity` works
- [ ] `jq . ~/pull-secret.json` parses successfully
- [ ] No Satellite/RHN configuration (not needed)

## Troubleshooting

### AWS CLI Commands Fail

```bash
# Check credentials file format
cat ~/.aws/credentials

# Verify credentials are correct
aws sts get-caller-identity --debug
```

### Pull Secret Invalid

```bash
# Validate JSON syntax
jq . ~/pull-secret.json

# If error, re-download from console.redhat.com
```

### Can't Access OpenShift Install Pull Secret

```bash
# Need a Red Hat account - create one (free) at:
open https://sso.redhat.com/auth/realms/redhat-external/login-actions/registration

# After registration, get pull secret
open https://console.redhat.com/openshift/install/pull-secret
```

## Next Steps

Once credentials are configured and verified:
→ [04-SNO_CONFIG_GUIDE.md](04-SNO_CONFIG_GUIDE.md)

## Additional Resources

- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [OpenShift Pull Secret](https://console.redhat.com/openshift/install/pull-secret)
- [AgnosticD Secrets Management](https://github.com/redhat-cop/agnosticd/blob/development/docs/Preparing_your_workstation.adoc)

