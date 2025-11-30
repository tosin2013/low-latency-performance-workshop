# Deployment Improvement Action Plan
**Based on AgnosticD Audit Report**  
**Priority-Ordered Improvements**

---

## 🎯 Quick Wins (Do Now - 1 Hour)

### 1. Add Variable Documentation
**Status**: In Progress  
**Priority**: High  
**Effort**: 30 minutes

Create `agnosticd/ansible/configs/ocp4-cluster/README.adoc`:

```asciidoc
= OCP4 Cluster on AWS Configuration

This configuration deploys OpenShift 4 clusters on AWS using IPI method.

== Required Variables

[cols="1,3,1"]
|===
|Variable |Description |Example

|`guid`
|Unique identifier for deployment
|`test-student1`

|`ocp4_pull_secret`
|Pull secret from console.redhat.com
|`'{"auths":...}'`

|`aws_access_key_id`
|AWS IAM access key
|From AWS Console

|`aws_secret_access_key`
|AWS IAM secret key
|From AWS Console

|===

== Optional Variables

[cols="1,3,1"]
|===
|Variable |Description |Default

|`master_instance_type`
|EC2 instance type for masters
|`m6i.xlarge`

|`worker_instance_count`
|Number of worker nodes
|`2`

|`ocp_version`
|OpenShift version
|`4.17`

|===

== Sample Deployment

[source,bash]
----
ansible-playbook ansible/main.yml \
  -e @configs/ocp4-cluster/sample_vars_ec2.yml \
  -e @~/secrets.yml \
  -e guid=test-student1 \
  -e ACTION=provision
----

== Troubleshooting

=== Issue: VPC Limit Exceeded
*Solution*: Check AWS service quotas and request increase

=== Issue: Pull Secret Invalid
*Solution*: Verify JSON format with `jq . pull-secret.json`
```

**Reference**: [AgnosticD Config README Pattern](https://github.com/redhat-cop/agnosticd/blob/development/ansible/configs/ocp4-cluster/README.adoc)

---

### 2. Add Pre-Flight Validation Script
**Priority**: High  
**Effort**: 30 minutes

Create `workshop-scripts/00-preflight-check.sh`:

```bash
#!/bin/bash
# Pre-flight checks before deployment

set -e

echo "=== AgnosticD Deployment Pre-Flight Checks ==="
echo ""

ERRORS=0
WARNINGS=0

# Check AWS credentials
echo "Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
  echo "  ✅ AWS credentials valid"
else
  echo "  ❌ AWS credentials invalid or missing"
  ERRORS=$((ERRORS + 1))
fi

# Check pull secret
echo "Checking OpenShift pull secret..."
if [ -f ~/pull-secret.json ]; then
  if jq empty ~/pull-secret.json 2>/dev/null; then
    echo "  ✅ Pull secret valid JSON"
  else
    echo "  ❌ Pull secret invalid JSON"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ❌ Pull secret not found at ~/pull-secret.json"
  ERRORS=$((ERRORS + 1))
fi

# Check secrets file
echo "Checking secrets file..."
if [ -f ~/secrets.yml ]; then
  echo "  ✅ Secrets file exists"
  
  # Validate it contains required fields
  if grep -q "aws_access_key_id" ~/secrets.yml; then
    echo "  ✅ AWS credentials in secrets file"
  else
    echo "  ⚠️  AWS credentials missing from secrets file"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  ❌ Secrets file not found at ~/secrets.yml"
  ERRORS=$((ERRORS + 1))
fi

# Check AWS service quotas
echo "Checking AWS service quotas..."
VCPU_LIMIT=$(aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-2 \
  --query 'Quota.Value' \
  --output text 2>/dev/null || echo "0")

if [ "${VCPU_LIMIT}" -ge 480 ]; then
  echo "  ✅ vCPU limit sufficient (${VCPU_LIMIT})"
else
  echo "  ⚠️  vCPU limit may be insufficient (${VCPU_LIMIT})"
  echo "     Recommended: 480+ for 30 students"
  WARNINGS=$((WARNINGS + 1))
fi

# Check VPC limit
echo "Checking VPC quotas..."
VPC_COUNT=$(aws ec2 describe-vpcs --region us-east-2 --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
VPC_LIMIT=$(aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --region us-east-2 \
  --query 'Quota.Value' \
  --output text 2>/dev/null || echo "5")

AVAILABLE_VPCS=$((VPC_LIMIT - VPC_COUNT))
echo "  VPCs available: ${AVAILABLE_VPCS} of ${VPC_LIMIT}"

if [ "${AVAILABLE_VPCS}" -lt 30 ]; then
  echo "  ⚠️  May not have enough VPCs for all students"
  WARNINGS=$((WARNINGS + 1))
else
  echo "  ✅ VPC quota sufficient"
fi

# Summary
echo ""
echo "=== Pre-Flight Check Summary ==="
echo "Errors:   ${ERRORS}"
echo "Warnings: ${WARNINGS}"
echo ""

if [ ${ERRORS} -gt 0 ]; then
  echo "❌ Pre-flight checks FAILED"
  echo "   Fix errors before proceeding"
  exit 1
elif [ ${WARNINGS} -gt 0 ]; then
  echo "⚠️  Pre-flight checks PASSED with warnings"
  echo "   Review warnings before proceeding"
  exit 0
else
  echo "✅ Pre-flight checks PASSED"
  echo "   Ready for deployment"
  exit 0
fi
```

**Usage**:
```bash
./workshop-scripts/00-preflight-check.sh
```

---

## 📋 Short-Term Improvements (Week 1-2)

### 3. Reorganize Variable Files
**Priority**: Medium  
**Effort**: 2 hours

Split variables into logical concerns:

```bash
agnosticd/ansible/configs/ocp4-cluster/
├── default_vars.yml                    # Core defaults
├── default_vars_ec2.yml                # AWS-specific (existing)
└── sample_vars/
    ├── common.yml                      # NEW: Common settings
    ├── aws-production.yml              # NEW: Production AWS config
    ├── aws-development.yml             # NEW: Dev AWS config
    └── ocp-417.yml                     # NEW: OCP 4.17 specific
```

**common.yml**:
```yaml
---
# Common settings for all deployments
env_type: ocp4-cluster
cloud_provider: ec2
install_student_user: false
software_to_deploy: none
```

**aws-production.yml**:
```yaml
---
# Production AWS configuration
aws_region: us-east-2
subdomain_base_suffix: ".dynamic.redhatworkshops.io"

# Capacity reservations for reliability
agnosticd_aws_capacity_reservation_enable: true
agnosticd_aws_capacity_reservation_single_zone: false
```

**aws-development.yml**:
```yaml
---
# Development AWS configuration
aws_region: us-east-2
subdomain_base_suffix: ".sandbox.opentlc.com"

# No capacity reservations for dev
agnosticd_aws_capacity_reservation_enable: false
```

**ocp-417.yml**:
```yaml
---
# OpenShift 4.17 specific configuration
ocp_version: "4.17"
openshift_version: "4.17"

master_instance_type: m6i.xlarge
worker_instance_type: m6i.2xlarge
worker_instance_count: 2
```

**Usage**:
```bash
# Production deployment
ansible-playbook ansible/main.yml \
  -e @configs/ocp4-cluster/sample_vars/common.yml \
  -e @configs/ocp4-cluster/sample_vars/aws-production.yml \
  -e @configs/ocp4-cluster/sample_vars/ocp-417.yml \
  -e @~/secrets.yml \
  -e guid=test-student1

# Development deployment
ansible-playbook ansible/main.yml \
  -e @configs/ocp4-cluster/sample_vars/common.yml \
  -e @configs/ocp4-cluster/sample_vars/aws-development.yml \
  -e @configs/ocp4-cluster/sample_vars/ocp-417.yml \
  -e @~/secrets.yml \
  -e guid=dev-student1
```

**Reference**: [AgnosticD Variable Organization](https://github.com/redhat-cop/agnosticd/blob/development/ansible/roles_ocp_workloads/ocp4_workload_plus/readme.adoc)

---

### 4. Add Deployment Validation
**Priority**: High  
**Effort**: 1 hour

Create `workshop-scripts/05-verify-deployment.sh`:

```bash
#!/bin/bash
# Verify deployment completed successfully

GUID=${1:-test-student1}

echo "=== Verifying Deployment: ${GUID} ==="
echo ""

# Check if deployment directory exists
if [ ! -d ~/agnosticd-output/${GUID} ]; then
  echo "❌ Deployment directory not found"
  exit 1
fi

echo "✅ Deployment directory exists"

# Check for kubeconfig
if [ -f ~/agnosticd-output/${GUID}/kubeconfig ]; then
  echo "✅ Kubeconfig file present"
else
  echo "❌ Kubeconfig file missing"
  exit 1
fi

# Test cluster access
echo "Testing cluster access..."
export KUBECONFIG=~/agnosticd-output/${GUID}/kubeconfig

if oc whoami &>/dev/null; then
  echo "✅ Cluster accessible"
  echo "   User: $(oc whoami)"
  echo "   Server: $(oc whoami --show-server)"
else
  echo "❌ Cannot access cluster"
  exit 1
fi

# Check cluster version
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null)
if [ -n "${OCP_VERSION}" ]; then
  echo "✅ Cluster version: ${OCP_VERSION}"
else
  echo "⚠️  Cannot determine cluster version"
fi

# Check cluster operators
echo "Checking cluster operators..."
NOT_AVAILABLE=$(oc get clusteroperators -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Available" and .status=="False")) | .metadata.name')

if [ -z "${NOT_AVAILABLE}" ]; then
  echo "✅ All cluster operators available"
else
  echo "⚠️  Some operators not available:"
  echo "${NOT_AVAILABLE}"
fi

# Check nodes
NODE_COUNT=$(oc get nodes --no-headers | wc -l)
echo "✅ Nodes: ${NODE_COUNT}"
oc get nodes

# Summary
echo ""
echo "=== Deployment Verification Complete ==="
echo "Cluster: ${GUID}"
echo "Status: ✅ Healthy"
echo ""
echo "Access details saved in:"
echo "  ~/agnosticd-output/${GUID}/"
```

**Reference**: [AgnosticD Post-Deployment Validation](https://github.com/redhat-cop/agnosticd/blob/development/ansible/roles_ocp_workloads/)

---

## 🚀 Long-Term Enhancements (Month 1-2)

### 5. Implement Capacity Reservations
**Priority**: High (for production)  
**Effort**: 4 hours

Add to `default_vars_ec2.yml`:

```yaml
# AWS Capacity Reservations for Production
# Ensures instance availability during workshops
agnosticd_aws_capacity_reservation_enable: true
agnosticd_aws_capacity_reservation_single_zone: false
agnosticd_aws_capacity_reservation_distinct: false

# Reserve capacity for 30 students
agnosticd_aws_capacity_reservations:
  # Bastion hosts (one per student)
  bastion:
    - instance_type: "{{ bastion_instance_type | default('t3.medium') }}"
      instance_count: 30
      instance_platform: "{{ bastion_instance_platform | default('Linux/UNIX') }}"
  
  # Master nodes (3 per cluster)
  masters:
    - instance_type: "{{ master_instance_type | default('m6i.xlarge') }}"
      instance_count: 90  # 30 clusters × 3 masters
      instance_platform: Linux/UNIX
  
  # Worker nodes (2 per cluster)
  workers:
    - instance_type: "{{ worker_instance_type | default('m6i.2xlarge') }}"
      instance_count: 60  # 30 clusters × 2 workers
      instance_platform: Linux/UNIX
```

**Cost Impact**:
- Capacity reservations have no additional cost
- Only pay for instances when running
- Guarantees availability during workshop dates

**Reference**: [AWS Capacity Reservations](https://github.com/redhat-cop/agnosticd/blob/development/ansible/roles-infra/infra-aws-capacity-reservation/readme.adoc)

---

### 6. Add Multi-Zone Support (Optional)
**Priority**: Low  
**Effort**: 6 hours

For HA demonstration purposes:

```yaml
# Multi-AZ High Availability Configuration
agnosticd_aws_capacity_reservation_distinct: true

agnosticd_aws_capacity_reservations:
  az1:  # us-east-2a
    - instance_type: "{{ bastion_instance_type }}"
      instance_count: 1
    - instance_type: "{{ master_instance_type }}"
      instance_count: 1
  
  az2:  # us-east-2b
    - instance_type: "{{ master_instance_type }}"
      instance_count: 1
    - instance_type: "{{ worker_instance_type }}"
      instance_count: 1
  
  az3:  # us-east-2c
    - instance_type: "{{ master_instance_type }}"
      instance_count: 1
    - instance_type: "{{ worker_instance_type }}"
      instance_count: 1

# Use the results for zone assignments
openshift_controlplane_aws_zones_odcr:
  - "{{ agnosticd_aws_capacity_reservation_results.reservations.az1.availability_zone }}"
  - "{{ agnosticd_aws_capacity_reservation_results.reservations.az2.availability_zone }}"
  - "{{ agnosticd_aws_capacity_reservation_results.reservations.az3.availability_zone }}"

openshift_machineset_aws_zones_odcr:
  - "{{ agnosticd_aws_capacity_reservation_results.reservations.az2.availability_zone }}"
  - "{{ agnosticd_aws_capacity_reservation_results.reservations.az3.availability_zone }}"
```

**Benefits**:
- Demonstrates production-grade HA
- Survives AZ failures
- Better for enterprise workshops

**Drawbacks**:
- More complex
- Slightly higher costs
- Longer deployment time

**Reference**: [Multi-Zone Configuration](https://github.com/redhat-cop/agnosticd/blob/development/ansible/roles-infra/infra-aws-capacity-reservation/readme.adoc)

---

## 📊 Implementation Priority Matrix

| Task | Priority | Effort | Impact | When |
|------|----------|--------|--------|------|
| Variable Documentation | High | Low | High | Now |
| Pre-Flight Checks | High | Low | High | Now |
| Deployment Validation | High | Low | High | Week 1 |
| Variable Reorganization | Medium | Medium | Medium | Week 1-2 |
| Capacity Reservations | High | Medium | High | Before Production |
| Multi-Zone Support | Low | High | Medium | Optional |

---

## ✅ Implementation Checklist

### Week 1 (Immediate)
- [ ] Create README.adoc with variable documentation
- [ ] Create pre-flight check script
- [ ] Test pre-flight script with current deployment
- [ ] Create deployment validation script
- [ ] Test validation script on test-student1

### Week 2 (Short-term)
- [ ] Reorganize variables into separate files
- [ ] Update deployment scripts to use new structure
- [ ] Test multi-file variable deployment
- [ ] Document new variable organization
- [ ] Update workshop documentation

### Production Prep (Before Workshop)
- [ ] Implement capacity reservations
- [ ] Test capacity reservation deployment
- [ ] Verify all 30 student allocations
- [ ] Document capacity reservation process
- [ ] Create runbook for workshop day

### Optional Enhancements
- [ ] Evaluate need for multi-zone
- [ ] If needed, implement multi-zone config
- [ ] Test multi-zone deployment
- [ ] Document multi-zone benefits

---

## 🎯 Success Criteria

After implementing improvements:

1. **Pre-deployment**:
   - [ ] All pre-flight checks pass automatically
   - [ ] No manual credential verification needed
   - [ ] AWS quotas validated before deployment

2. **During deployment**:
   - [ ] Variables clearly organized by concern
   - [ ] Easy to switch between dev/prod configs
   - [ ] Capacity guaranteed for all students

3. **Post-deployment**:
   - [ ] Automated validation confirms success
   - [ ] Clear output shows cluster health
   - [ ] Documentation matches reality

4. **Maintainability**:
   - [ ] New contributors understand variables
   - [ ] README answers common questions
   - [ ] Troubleshooting guide covers issues

---

## 📚 References

All improvements based on:
- [AgnosticD Best Practices](https://context7.com/redhat-cop/agnosticd)
- [OCP4 Cluster Config](https://github.com/redhat-cop/agnosticd/blob/development/ansible/configs/ocp4-cluster/)
- [AWS Capacity Reservations](https://github.com/redhat-cop/agnosticd/blob/development/ansible/roles-infra/infra-aws-capacity-reservation/)
- Red Hat Consulting Workshop Patterns

---

**Action Plan Created**: November 28, 2025  
**Target Completion**: Immediate items by Week 1, Production prep before workshop

