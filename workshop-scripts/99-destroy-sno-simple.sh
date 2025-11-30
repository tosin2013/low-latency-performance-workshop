#!/bin/bash
# Simple direct cleanup of SNO deployment (bypasses AgnosticD)

set -e

STUDENT_NAME=${1:-student1}
DEPLOYMENT_MODE=${2:-rhpds}
GUID="test-${STUDENT_NAME}"
CLUSTER_NAME="workshop-${STUDENT_NAME}"
# Stack name NOW matches project_tag which includes GUID
# This makes each student's deployment unique!
ENV_TYPE="low-latency-workshop-sno"
STACK_NAME="${ENV_TYPE}-${GUID}"
KEY_NAME="ssh_provision_${GUID}"
AWS_REGION="us-east-2"

echo "============================================"
echo " Simple SNO Cleanup (Direct AWS/OC)"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: ${GUID}"
echo "Stack: ${STACK_NAME}"
echo "Region: ${AWS_REGION}"
echo ""
echo "⚠️  This will DELETE all resources!"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Step 1: Remove from RHACM (if RHPDS mode)
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo "[1/6] Removing ManagedCluster from RHACM..."
    if oc get managedcluster ${CLUSTER_NAME} &>/dev/null; then
        oc delete managedcluster ${CLUSTER_NAME} --wait=false || echo "  ⚠️  Failed to delete ManagedCluster (may not exist)"
        echo "  ✓ ManagedCluster ${CLUSTER_NAME} deleted"
    else
        echo "  → ManagedCluster ${CLUSTER_NAME} not found (already deleted or never created)"
    fi
else
    echo "[1/6] Skipping RHACM cleanup (standalone mode)"
fi

# Step 2: Delete CloudFormation Stack
echo ""
echo "[2/6] Deleting CloudFormation stack..."
if aws cloudformation describe-stacks --region ${AWS_REGION} --stack-name ${STACK_NAME} &>/dev/null; then
    echo "  → Deleting stack ${STACK_NAME}..."
    aws cloudformation delete-stack \
        --region ${AWS_REGION} \
        --stack-name ${STACK_NAME}
    
    echo "  → Waiting for stack deletion (this may take 5-10 minutes)..."
    aws cloudformation wait stack-delete-complete \
        --region ${AWS_REGION} \
        --stack-name ${STACK_NAME} 2>&1 | head -5 || echo "  ⚠️  Stack deletion in progress or already deleted"
    
    echo "  ✓ CloudFormation stack deleted"
else
    echo "  → Stack ${STACK_NAME} not found (already deleted or never created)"
fi

# Step 2.5: Check for and terminate orphaned EC2 instances
echo ""
echo "[2.5/6] Checking for orphaned EC2 instances..."
ORPHANED_INSTANCES=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" "Name=instance-state-name,Values=running,stopped,stopping" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text 2>/dev/null)

if [ -n "${ORPHANED_INSTANCES}" ]; then
    echo "  → Found orphaned instances: ${ORPHANED_INSTANCES}"
    echo "  → Terminating instances..."
    aws ec2 terminate-instances \
        --region ${AWS_REGION} \
        --instance-ids ${ORPHANED_INSTANCES}
    echo "  ✓ Orphaned instances terminated"
else
    echo "  → No orphaned instances found"
fi

# Step 3: Delete SSH Key
echo ""
echo "[3/6] Deleting SSH key..."
if aws ec2 describe-key-pairs --region ${AWS_REGION} --key-names ${KEY_NAME} &>/dev/null; then
    aws ec2 delete-key-pair \
        --region ${AWS_REGION} \
        --key-name ${KEY_NAME}
    echo "  ✓ SSH key ${KEY_NAME} deleted"
else
    echo "  → SSH key ${KEY_NAME} not found (already deleted or never created)"
fi

# Step 4: Clean up S3 bucket (if template was uploaded)
echo ""
echo "[4/6] Checking for S3 buckets with CloudFormation templates..."
S3_BUCKETS=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'cf-templates') && contains(Name, '${AWS_REGION}')].Name" \
  --output text 2>/dev/null)

if [ -n "${S3_BUCKETS}" ]; then
    for BUCKET in ${S3_BUCKETS}; do
        # Check if bucket has objects with our GUID
        OBJECTS=$(aws s3api list-objects-v2 \
          --bucket ${BUCKET} \
          --query "Contents[?contains(Key, '${GUID}')].Key" \
          --output text 2>/dev/null)
        
        if [ -n "${OBJECTS}" ]; then
            echo "  → Found template objects in bucket: ${BUCKET}"
            echo "  → Deleting objects..."
            for OBJ in ${OBJECTS}; do
                aws s3 rm s3://${BUCKET}/${OBJ} 2>/dev/null
            done
            
            # Check if bucket is now empty and delete if so
            REMAINING=$(aws s3api list-objects-v2 --bucket ${BUCKET} --query 'Contents' --output text 2>/dev/null)
            if [ -z "${REMAINING}" ]; then
                echo "  → Bucket empty, deleting: ${BUCKET}"
                aws s3api delete-bucket --bucket ${BUCKET} --region ${AWS_REGION} 2>/dev/null
            fi
            echo "  ✓ CloudFormation template cleaned from S3"
        fi
    done
else
    echo "  → No S3 buckets found"
fi

# Step 5: Clean up local output directory and template files
echo ""
echo "[5/6] Cleaning up local files..."
OUTPUT_DIR=~/agnosticd-output/${GUID}
if [ -d "${OUTPUT_DIR}" ]; then
    rm -rf ${OUTPUT_DIR}
    echo "  ✓ Removed ${OUTPUT_DIR}"
else
    echo "  → Output directory not found"
fi

# Clean up any local CloudFormation template files
TEMPLATE_FILES=$(find /tmp -name "*${GUID}*.ec2_cloud_template" 2>/dev/null)
if [ -n "${TEMPLATE_FILES}" ]; then
    echo "  → Removing CloudFormation template files..."
    rm -f ${TEMPLATE_FILES}
    echo "  ✓ Template files removed"
else
    echo "  → No template files found"
fi

echo ""
echo "============================================"
echo " Cleanup Complete!"
echo "============================================"
echo ""
echo "Verification commands:"
echo ""
echo "1. Check CloudFormation:"
echo "   aws cloudformation describe-stacks --region ${AWS_REGION} --stack-name ${STACK_NAME}"
echo "   (should return: Stack with id ... does not exist)"
echo ""
echo "2. Check EC2 instances:"
echo "   aws ec2 describe-instances --region ${AWS_REGION} --filters \"Name=tag:guid,Values=${GUID}\" --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'"
echo "   (should return: [])"
echo ""
echo "3. Check RHACM:"
echo "   oc get managedcluster ${CLUSTER_NAME}"
echo "   (should return: NotFound)"
echo ""
echo "✅ All resources cleaned up for ${STUDENT_NAME}"
echo ""

