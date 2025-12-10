#!/bin/bash
# Check SNO cluster deployment status

set -e

STUDENT_NAME=${1:-user1}
GUID="workshop-${STUDENT_NAME}"
AWS_REGION=${2:-us-east-2}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🔍 SNO CLUSTER STATUS CHECK                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: ${GUID}"
echo "Region: ${AWS_REGION}"
echo ""

# Check for bastion
echo "[1/5] Checking bastion instance..."
BASTION_IP=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters \
    "Name=tag:guid,Values=${GUID}" \
    "Name=tag:AnsibleGroup,Values=bastions" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" == "None" ]; then
  echo "  ✗ Bastion not found!"
  exit 1
fi
echo "  ✓ Bastion found: ${BASTION_IP}"

# Check SSH key
echo ""
echo "[2/5] Checking SSH key..."
SSH_KEY="${HOME}/agnosticd-output/${GUID}/ssh_provision_${GUID}"
if [ ! -f "$SSH_KEY" ]; then
  echo "  ✗ SSH key not found at: ${SSH_KEY}"
  exit 1
fi
echo "  ✓ SSH key found"

# Check if installer is still running
echo ""
echo "[3/5] Checking if installer is still running..."
INSTALLER_RUNNING=$(ssh -i "$SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=10 \
  ec2-user@${BASTION_IP} \
  "ps aux | grep -v grep | grep 'openshift-install' || echo 'not-running'" 2>/dev/null || echo "ssh-failed")

if [ "$INSTALLER_RUNNING" == "ssh-failed" ]; then
  echo "  ⚠️  Could not SSH to bastion"
elif [ "$INSTALLER_RUNNING" == "not-running" ]; then
  echo "  ✓ Installer process not running (either completed or failed)"
else
  echo "  🔄 Installer still running!"
  echo "     ${INSTALLER_RUNNING}"
fi

# Check for SNO EC2 instances
echo ""
echo "[4/5] Checking for SNO EC2 instances..."
SNO_INSTANCES=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters \
    "Name=tag:kubernetes.io/cluster/${GUID},Values=owned" \
    "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || echo "")

if [ -z "$SNO_INSTANCES" ]; then
  echo "  ⚠️  No SNO instances found (installer may not have started infrastructure creation)"
else
  echo "  ✓ SNO instances found:"
  echo "$SNO_INSTANCES"
fi

# Check for VPC
echo ""
echo "[5/5] Checking for SNO VPC..."
SNO_VPC=$(aws ec2 describe-vpcs \
  --region ${AWS_REGION} \
  --filters "Name=tag:kubernetes.io/cluster/${GUID},Values=owned" \
  --query 'Vpcs[0].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || echo "")

if [ -z "$SNO_VPC" ]; then
  echo "  ⚠️  No SNO VPC found"
else
  echo "  ✓ SNO VPC found:"
  echo "$SNO_VPC"
fi

# Try to check cluster status from bastion
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Attempting to check cluster status from bastion..."
echo "═══════════════════════════════════════════════════════════"
echo ""

ssh -i "$SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=10 \
  ec2-user@${BASTION_IP} << 'EOSSH' || true

echo "Checking installation directory..."
if [ -d ~/workshop-user1 ]; then
  echo "✓ Installation directory exists: ~/workshop-user1"
  
  echo ""
  echo "Checking for kubeconfig..."
  if [ -f ~/workshop-user1/auth/kubeconfig ]; then
    echo "✓ Kubeconfig found!"
    
    export KUBECONFIG=~/workshop-user1/auth/kubeconfig
    
    echo ""
    echo "Cluster API:"
    grep server ~/workshop-user1/auth/kubeconfig | awk '{print $2}' || echo "Could not extract API URL"
    
    echo ""
    echo "Attempting to connect to cluster..."
    if /usr/local/bin/oc get nodes 2>/dev/null; then
      echo ""
      echo "✅ CLUSTER IS UP AND ACCESSIBLE!"
      
      echo ""
      echo "Cluster version:"
      /usr/local/bin/oc get clusterversion
      
      echo ""
      echo "Cluster operators:"
      /usr/local/bin/oc get co | head -20
    else
      echo "⚠️  Could not connect to cluster (may still be initializing)"
    fi
  else
    echo "⚠️  Kubeconfig not found"
  fi
  
  echo ""
  echo "Checking install log (last 50 lines)..."
  if [ -f ~/workshop-user1/.openshift_install.log ]; then
    tail -50 ~/workshop-user1/.openshift_install.log
  fi
else
  echo "✗ Installation directory not found"
fi

EOSSH

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Status check complete!"
echo "═══════════════════════════════════════════════════════════"



