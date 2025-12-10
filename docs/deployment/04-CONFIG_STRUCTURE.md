# AgnosticD Config Structure

## Overview

Our `low-latency-workshop-sno` config extends the proven `ocp4-cluster` config to provision Single Node OpenShift clusters with optional RHACM integration.

## Directory Structure

```
agnosticd-configs/low-latency-workshop-sno/
├── README.adoc                    # Configuration documentation
├── default_vars.yml               # SNO-specific defaults
├── default_vars_ec2.yml           # AWS-specific settings
├── env_vars.yml                   # SNO overrides (1 master, 0 workers)
│
├── pre_infra.yml                  # Validates and delegates to ocp4-cluster
├── post_infra.yml                 # Confirms infrastructure ready
├── pre_software.yml               # Pre-installation tasks
├── software.yml                   # OpenShift installation (delegates)
├── post_software.yml              # RHACM integration (our custom!)
├── destroy_env.yml                # Cleanup (RHACM + infrastructure)
│
└── sample_vars/
    ├── rhpds.yml                 # RHPDS mode (auto-import to RHACM)
    └── standalone.yml            # Standalone mode (no RHACM)
```

## How It Works

### Config Extension Pattern

Our config uses the "include pattern" to leverage `ocp4-cluster`'s proven infrastructure and OpenShift provisioning:

```yaml
# In pre_infra.yml
- name: Include ocp4-cluster pre_infra tasks
  include_tasks: "{{ playbook_dir }}/configs/ocp4-cluster/pre_infra.yml"
```

This allows us to:
- ✅ Reuse proven infrastructure provisioning
- ✅ Reuse proven OpenShift installation
- ✅ Add our custom RHACM integration layer
- ✅ Maintain SNO-specific configuration

### Execution Flow

```
AgnosticD main.yml
    ↓
1. pre_infra.yml
   - Sets SNO variables (master_instance_count=1, worker_instance_count=0)
   - Validates requirements
   - Includes ocp4-cluster/pre_infra.yml → Infrastructure provisioning
    ↓
2. post_infra.yml
   - Confirms infrastructure ready
   - Includes ocp4-cluster/post_infra.yml
    ↓
3. pre_software.yml
   - Pre-installation tasks
   - Includes ocp4-cluster/pre_software.yml
    ↓
4. software.yml
   - OpenShift installation
   - Includes ocp4-cluster/software.yml
    ↓
5. post_software.yml (OUR CUSTOM!)
   - Logs into hub cluster
   - Logs into new SNO cluster
   - Creates ManagedCluster + auto-import-secret
   - Waits for cluster join
   - No delegation - pure custom code
```

## Key Files Explained

### env_vars.yml

Sets SNO-specific overrides that apply throughout the deployment:

```yaml
---
# SNO-specific overrides
master_instance_count: 1
worker_instance_count: 0
bastion_instance_count: 0
master_instance_type: "{{ sno_instance_type | default('m5.4xlarge') }}"
```

These variables override ocp4-cluster's defaults to create a single-node cluster.

### default_vars.yml

Defines SNO-specific default variables:

```yaml
---
env_type: low-latency-workshop-sno
deployment_type: sno
guid: "workshop-{{ student_name }}"
ocp_version: "4.20"
sno_instance_type: m5.4xlarge

# RHACM Integration (RHPDS mode)
auto_import_to_rhacm: true  # Set by sample_vars
managedclusterset: "workshop-clusters"

# Workshop-specific
cluster_labels:
  workshop: "low-latency"
  student: "{{ student_name }}"
  environment: "target"
```

### post_software.yml (The RHACM Magic!)

Based on AgnosticD's `hybrid-cloud-binder` proven pattern:

```yaml
---
- name: RHACM Integration (RHPDS Mode)
  when:
    - auto_import_to_rhacm | default(false) | bool
    - rhacm_hub_api is defined
  block:
    # 1. Login to hub cluster
    - kubernetes.core.k8s_auth:
        host: "{{ rhacm_hub_api }}"
        kubeconfig: "{{ rhacm_hub_kubeconfig }}"
    
    # 2. Login to SNO cluster
    - kubernetes.core.k8s_auth:
        host: "{{ sno_api_url }}"
        kubeconfig: "{{ sno_kubeconfig }}"
    
    # 3. Create namespace on hub
    - kubernetes.core.k8s:
        state: present
        kind: Namespace
        name: "workshop-{{ student_name }}"
    
    # 4. Import SNO (ManagedCluster + auto-import-secret + KlusterletAddonConfig)
    # 5. Wait for cluster to join
    # 6. Add to ManagedClusterSet
```

**Key Insight**: The `auto-import-secret` contains the SNO cluster's API token and endpoint. RHACM uses this to automatically install the klusterlet on the SNO - no manual work needed!

## Sample Vars Files

### sample_vars/rhpds.yml (RHPDS Mode)

```yaml
---
# RHPDS mode - deploys SNO and auto-imports to RHACM
cloud_provider: ec2
aws_region: us-east-1
env_type: low-latency-workshop-sno

# Enable RHACM auto-import
auto_import_to_rhacm: true

# Hub integration (passed from environment)
rhacm_hub_api: "{{ lookup('env', 'HUB_API_URL') }}"
rhacm_hub_kubeconfig: "{{ lookup('env', 'HUB_KUBECONFIG') }}"
```

### sample_vars/standalone.yml (Standalone Mode)

```yaml
---
# Standalone mode - deploys SNO without RHACM integration
cloud_provider: ec2
aws_region: us-east-1
env_type: low-latency-workshop-sno

# Disable RHACM auto-import
auto_import_to_rhacm: false
```

## Deployment Modes

### RHPDS Mode (Default)
- **auto_import_to_rhacm: true**
- Provisions SNO on AWS
- Logs into hub cluster
- Creates RHACM resources
- Auto-imports SNO
- Result: SNO appears in RHACM as managed cluster

### Standalone Mode
- **auto_import_to_rhacm: false**
- Provisions SNO on AWS
- No hub integration
- Result: SNO accessible via kubeconfig only

## Required Variables

### Always Required
- `guid`: Unique identifier for deployment
- `student_name`: Student identifier
- `cloud_provider`: Cloud provider (ec2)
- `ocp4_pull_secret`: OpenShift pull secret (inline content!)
- `aws_access_key_id`: AWS access key
- `aws_secret_access_key`: AWS secret key

### RHPDS Mode Additional Requirements
- `rhacm_hub_api`: Hub cluster API URL
- `rhacm_hub_kubeconfig`: Path to hub kubeconfig
- `managedclusterset`: ManagedClusterSet name (optional)

## Best Practices

1. **Pull Secret**: Always use inline content in secrets file, not file lookups
2. **Testing**: Use standalone mode first to test SNO provisioning
3. **RHACM**: Verify hub cluster is healthy before RHPDS mode
4. **Cleanup**: Use destroy_env.yml to properly clean up (removes from RHACM first)

## Troubleshooting

### Config Not Found
```bash
# Ensure config is copied to AgnosticD
ls ~/agnosticd/ansible/configs/low-latency-workshop-sno/
```

### Missing Files
All these files must exist:
- pre_infra.yml
- post_infra.yml
- pre_software.yml ← Often forgotten!
- software.yml
- post_software.yml
- destroy_env.yml

### Pull Secret Issues
Don't use: `{{ lookup("file", "~/pull-secret.json") }}`  
Do use: Direct content in secrets file

## References

- Base Config: `~/agnosticd/ansible/configs/ocp4-cluster/`
- RHACM Pattern: `~/agnosticd/ansible/configs/hybrid-cloud-binder/`
- Workshop Scripts: `workshop-scripts/03-test-single-sno.sh`

