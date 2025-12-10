# Setting Up ansible-navigator

## Overview

This document covers **Part 1 of 2** for deployment setup:

1. **This document (02)**: Install and configure ansible-navigator
2. **Next document (03)**: Configure AWS credentials and create `~/secrets-ec2.yml`

After completing both documents, you'll be ready to deploy SNO clusters.

## Why ansible-navigator?

**ansible-navigator** is AgnosticD's preferred deployment method because:

✅ **Containerized Execution Environments**: All dependencies pre-packaged  
✅ **Reproducible**: Same environment on every machine  
✅ **No Version Conflicts**: Isolated from system Python/Ansible  
✅ **AgnosticD Maintained**: Official images with all required collections  

Traditional `ansible-playbook` still works, but ansible-navigator is the modern, recommended approach.

## Installation Steps

### Step 1: Verify podman is Available

```bash
# Check if podman is installed (should be on RHEL 9)
podman --version

# If not installed
sudo dnf install -y podman
```

### Step 2: Install ansible-navigator

```bash
# Install via pip3 (user-local installation)
pip3 install --user 'ansible-navigator[ansible-core]'

# Add to PATH
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
ansible-navigator --version
```

Expected output:
```
ansible-navigator 25.x.x
```

### Step 3: Create Configuration File

Create `~/.ansible-navigator.yaml`:

```bash
cat > ~/.ansible-navigator.yaml << 'EOF'
---
ansible-navigator:
  execution-environment:
    # Enable containerized execution
    enabled: true
    
    # Use AgnosticD's multi-cloud execution environment
    image: quay.io/agnosticd/ee-multicloud:latest
    
    # Container engine (podman recommended, docker also works)
    container-engine: podman
    
    # Pull policy
    pull:
      policy: missing  # Only pull if not present locally
    
    # Volume mounts - critical for accessing local files
    volume-mounts:
      - src: "~/"
        dest: "/runner"
        options: "Z"  # SELinux relabeling
    
  # Output mode
  mode: stdout  # Use 'interactive' for TUI debugging mode
  
  # Artifact saving
  playbook-artifact:
    enable: true
    save-as: "/runner/ansible-artifacts/{playbook_name}-artifact-{ts_utc}.json"
  
  # Logging
  logging:
    level: info
    append: false
EOF
```

### Step 4: Pull the Execution Environment Image

```bash
# Pull AgnosticD's multi-cloud execution environment
echo "Pulling execution environment (this may take a few minutes)..."
podman pull quay.io/agnosticd/ee-multicloud:latest

# Verify image is available
podman images | grep agnosticd
```

Expected output:
```
quay.io/agnosticd/ee-multicloud  latest  abc123def456  X days ago  XXX MB
```

### Step 5: Test ansible-navigator

```bash
# Test that ansible-navigator works
ansible-navigator --help

# Test with execution environment
cd ~/agnosticd
ansible-navigator run --help
```

## Understanding Volume Mounts

**Critical Concept**: The execution environment runs in a container, so it needs access to your files.

### Volume Mount Configuration

```yaml
volume-mounts:
  - src: "~/"              # Your home directory on host
    dest: "/runner"        # Path inside container
    options: "Z"           # SELinux context relabeling
```

### Path Translation

| Your Bastion Path | Container Path |
|-------------------|----------------|
| `~/secrets-ec2.yml` | `/runner/secrets-ec2.yml` |
| `~/agnosticd/` | `/runner/agnosticd/` |
| `~/.kube/config` | `/runner/.kube/config` |
| `~/pull-secret.json` | `/runner/pull-secret.json` |

**Good news**: ansible-navigator automatically translates `~/` paths, so you can use normal paths in commands.

## Usage Examples

### Basic Usage

```bash
cd ~/agnosticd

# Run playbook with execution environment
ansible-navigator run ansible/main.yml \
  -e @ansible/configs/test-empty-config/sample_vars.yml
```

### With Configuration File (Recommended)

Since you have `~/.ansible-navigator.yaml`, you can simplify commands:

```bash
# Configuration file is automatically loaded
ansible-navigator run ansible/main.yml \
  -e @ansible/configs/low-latency-workshop-sno/sample_vars/rhpds.yml \
  -e @~/secrets-ec2.yml \
  -e guid=test-student1
```

### Interactive Mode (for Debugging)

```bash
# Use interactive TUI
ansible-navigator run ansible/main.yml \
  --mode interactive \
  -e @ansible/configs/low-latency-workshop-sno/sample_vars/rhpds.yml \
  -e @~/secrets-ec2.yml
```

Interactive mode provides:
- Task-by-task navigation
- Inspect task results
- View full task details
- Replay capabilities

## Comparison: ansible-playbook vs ansible-navigator

### Old Way (ansible-playbook)

```bash
# Requires local Ansible installation
ansible-playbook ansible/main.yml \
  -e @ansible/configs/low-latency-workshop-sno/sample_vars.yml \
  -e @~/secrets-ec2.yml
```

### New Way (ansible-navigator)

```bash
# Uses containerized execution environment
ansible-navigator run ansible/main.yml \
  -e @ansible/configs/low-latency-workshop-sno/sample_vars.yml \
  -e @~/secrets-ec2.yml
```

**Key Differences**:
- `ansible-playbook` → `ansible-navigator run`
- Runs in container with all dependencies
- Consistent environment everywhere

## Troubleshooting

### Error: "ansible-navigator: command not found"

```bash
# Ensure PATH includes user bin
export PATH=$PATH:~/.local/bin

# Add to bashrc for persistence
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
```

### Error: "podman: command not found"

```bash
# Install podman
sudo dnf install -y podman
```

### Error: "Permission denied" with podman

```bash
# Verify user can run podman rootless
podman ps

# If issues, check podman setup
podman system info

# May need to restart session after podman install
```

### Error: "Volume mount failed"

```bash
# Check SELinux context
ls -Z ~/

# If needed, relabel home directory
restorecon -R ~/
```

### Error: "Cannot pull image"

```bash
# Check internet connectivity
curl -I https://quay.io

# Try pulling manually
podman pull quay.io/agnosticd/ee-multicloud:latest

# Check podman storage
podman info | grep -A5 "store:"
```

### Slow Image Pull

The execution environment image is ~1-2GB. First pull may take 5-10 minutes depending on connection.

```bash
# Monitor pull progress
podman pull --log-level debug quay.io/agnosticd/ee-multicloud:latest
```

## Verification Checklist

Before proceeding, verify:

- [ ] ansible-navigator installed and in PATH
- [ ] podman available and functional
- [ ] `~/.ansible-navigator.yaml` created
- [ ] Execution environment image pulled
- [ ] Test `ansible-navigator --help` works
- [ ] Can navigate to `~/agnosticd` directory

## Next Steps

Once ansible-navigator is set up and tested, you need to configure credentials:

**→ [03-AWS_CREDENTIALS.md](03-AWS_CREDENTIALS.md)**

The next document will guide you through:
- Setting up AWS credentials (`~/.aws/credentials`)
- Downloading your OpenShift pull secret
- Creating the AgnosticD secrets file (`~/secrets-ec2.yml`) ← **Required for deployment**

These credentials are required before you can deploy any SNO clusters.

## Additional Resources

- [ansible-navigator Documentation](https://ansible-navigator.readthedocs.io/)
- [AgnosticD Execution Environments](https://github.com/redhat-cop/agnosticd/tree/development/tools/execution_environments)
- [Podman Documentation](https://docs.podman.io/)

