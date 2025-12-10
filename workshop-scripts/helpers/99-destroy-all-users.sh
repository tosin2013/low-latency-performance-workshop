#!/bin/bash
# Destroy SNO clusters for multiple workshop users
#
# Usage:
#   ./99-destroy-all-users.sh [start_num] [end_num] [mode]
#
# Examples:
#   ./99-destroy-all-users.sh 1 30 rhpds       # Destroy users 1-30 with RHACM cleanup
#   ./99-destroy-all-users.sh 1 10 standalone  # Destroy users 1-10 without RHACM cleanup
#   ./99-destroy-all-users.sh 15 15 rhpds      # Destroy only user15

set -e

START_NUM=${1:-1}
END_NUM=${2:-30}
DEPLOYMENT_MODE=${3:-rhpds}  # rhpds or standalone
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"

NUM_STUDENTS=$((END_NUM - START_NUM + 1))

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     BULK SNO CLUSTER CLEANUP                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Students: ${START_NUM} to ${END_NUM} (${NUM_STUDENTS} total)"
echo "  Mode: ${DEPLOYMENT_MODE}"
echo ""

# Validate deployment mode
if [[ "${DEPLOYMENT_MODE}" != "rhpds" && "${DEPLOYMENT_MODE}" != "standalone" ]]; then
    echo "✗ Invalid deployment mode: ${DEPLOYMENT_MODE}"
    echo "Valid modes: rhpds, standalone"
    exit 1
fi

# Confirm destruction
echo "⚠️  WARNING: This will destroy all resources for users ${START_NUM}-${END_NUM}"
echo ""
echo "This includes:"
echo "  - AWS VPCs, EC2 instances, EBS volumes"
echo "  - Route53 DNS records"
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo "  - RHACM ManagedCluster resources"
fi
echo "  - Local output directories and SSH keys"
echo ""
read -p "Type 'DELETE' to confirm: " CONFIRM

if [ "${CONFIRM}" != "DELETE" ]; then
    echo "Aborted."
    exit 1
fi

# Check hub cluster access (for RHPDS mode)
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    if ! oc whoami &> /dev/null; then
        echo "⚠ Not logged into hub cluster (required for RHACM cleanup)"
        read -p "Continue without RHACM cleanup? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
            echo "Aborted."
            exit 1
        fi
        DEPLOYMENT_MODE="standalone"
    fi
fi

START_TIME=$(date +%s)
LOG_DIR="/tmp/workshop-cleanup-$(date +%Y%m%d-%H%M%S)"
mkdir -p ${LOG_DIR}

echo ""
echo "Starting cleanup..."
echo "Logs: ${LOG_DIR}"
echo ""

# Arrays to track results
declare -a SUCCESSFUL_CLEANUPS
declare -a FAILED_CLEANUPS

# Cleanup each user sequentially (safer than parallel)
for i in $(seq ${START_NUM} ${END_NUM}); do
    USER_NAME="user${i}"
    LOG_FILE="${LOG_DIR}/cleanup-${USER_NAME}.log"
    
    echo "────────────────────────────────────────────────────────────"
    echo "Cleaning up ${USER_NAME} ($((i - START_NUM + 1))/${NUM_STUDENTS})"
    echo "────────────────────────────────────────────────────────────"
    
    # Run cleanup script
    if ${WORKSHOP_DIR}/workshop-scripts/99-destroy-sno-complete.sh ${USER_NAME} ${DEPLOYMENT_MODE} > ${LOG_FILE} 2>&1; then
        echo "✓ ${USER_NAME}: Cleanup successful"
        SUCCESSFUL_CLEANUPS+=("${USER_NAME}")
    else
        echo "✗ ${USER_NAME}: Cleanup failed (check log)"
        FAILED_CLEANUPS+=("${USER_NAME}")
    fi
    
    echo ""
    
    # Brief pause between cleanups to avoid API throttling
    if [ $i -lt ${END_NUM} ]; then
        sleep 10
    fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$(( (END_TIME - START_TIME) / 60 ))

# Generate cleanup summary
echo "════════════════════════════════════════════════════════════"
echo "CLEANUP SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Duration: ${TOTAL_DURATION} minutes"
echo "✓ Successful: ${#SUCCESSFUL_CLEANUPS[@]}"
echo "✗ Failed: ${#FAILED_CLEANUPS[@]}"
echo ""

if [ ${#FAILED_CLEANUPS[@]} -gt 0 ]; then
    echo "Failed cleanups:"
    for user in "${FAILED_CLEANUPS[@]}"; do
        LOG_FILE="${LOG_DIR}/cleanup-${user}.log"
        ERROR=$(grep -i "error\|failed" ${LOG_FILE} | tail -1 || echo "Check log for details")
        echo "  ✗ ${user}"
        echo "    Log: ${LOG_FILE}"
        echo "    Error: ${ERROR}"
    done
    echo ""
    echo "Retry failed cleanups:"
    for user in "${FAILED_CLEANUPS[@]}"; do
        echo "  ./workshop-scripts/99-destroy-sno-complete.sh ${user} ${DEPLOYMENT_MODE}"
    done
    echo ""
fi

# Save summary
SUMMARY_FILE="${LOG_DIR}/cleanup-summary.txt"
cat > ${SUMMARY_FILE} << EOF
Bulk Cleanup Summary
════════════════════════════════════════════════════════════
Started: $(date -d @${START_TIME} '+%Y-%m-%d %H:%M:%S')
Completed: $(date -d @${END_TIME} '+%Y-%m-%d %H:%M:%S')
Duration: ${TOTAL_DURATION} minutes

Students: ${START_NUM} to ${END_NUM} (${NUM_STUDENTS} total)
Mode: ${DEPLOYMENT_MODE}

Results:
  ✓ Successful: ${#SUCCESSFUL_CLEANUPS[@]}
  ✗ Failed: ${#FAILED_CLEANUPS[@]}

Logs: ${LOG_DIR}

Successful:
$(printf "  %s\n" "${SUCCESSFUL_CLEANUPS[@]}")

Failed:
$(printf "  %s\n" "${FAILED_CLEANUPS[@]}")
EOF

echo "Summary saved to: ${SUMMARY_FILE}"
echo ""

# Verify RHACM cleanup (RHPDS mode)
if [ "${DEPLOYMENT_MODE}" == "rhpds" ] && oc whoami &> /dev/null; then
    echo "Verifying RHACM cleanup..."
    REMAINING_CLUSTERS=$(oc get managedcluster -l workshop=low-latency --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "${REMAINING_CLUSTERS}" -gt 0 ]; then
        echo "⚠ ${REMAINING_CLUSTERS} ManagedCluster(s) still exist:"
        oc get managedcluster -l workshop=low-latency
        echo ""
        echo "Manually delete remaining clusters:"
        echo "  oc delete managedcluster -l workshop=low-latency"
    else
        echo "✓ All ManagedClusters deleted"
    fi
    echo ""
fi

# Verify AWS cleanup
echo "Verifying AWS cleanup..."
AWS_REGION=$(grep "aws_region:" ~/secrets-ec2.yml | awk '{print $2}' 2>/dev/null || echo "us-east-1")

REMAINING_INSTANCES=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters "Name=tag:workshop,Values=low-latency" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`guid`].Value|[0]]' \
  --output text 2>/dev/null | wc -l || echo "0")

if [ "${REMAINING_INSTANCES}" -gt 0 ]; then
    echo "⚠ ${REMAINING_INSTANCES} EC2 instance(s) still running:"
    aws ec2 describe-instances \
      --region ${AWS_REGION} \
      --filters "Name=tag:workshop,Values=low-latency" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
      --query 'Reservations[*].Instances[*].[Tags[?Key==`guid`].Value|[0],InstanceId,State.Name]' \
      --output table
    echo ""
    echo "Manually terminate remaining instances if needed"
else
    echo "✓ No EC2 instances found"
fi
echo ""

# Check CloudFormation stacks
REMAINING_STACKS=$(aws cloudformation list-stacks \
  --region ${AWS_REGION} \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `workshop-user`)].StackName' \
  --output text 2>/dev/null | wc -w || echo "0")

if [ "${REMAINING_STACKS}" -gt 0 ]; then
    echo "⚠ ${REMAINING_STACKS} CloudFormation stack(s) still exist:"
    aws cloudformation list-stacks \
      --region ${AWS_REGION} \
      --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE \
      --query 'StackSummaries[?contains(StackName, `workshop-user`)].StackName' \
      --output table
    echo ""
else
    echo "✓ No CloudFormation stacks found"
fi
echo ""

echo "════════════════════════════════════════════════════════════"
echo "Cleanup complete!"
echo ""
echo "Next steps:"
echo "  1. Review summary: cat ${SUMMARY_FILE}"
if [ ${#FAILED_CLEANUPS[@]} -gt 0 ]; then
    echo "  2. Retry failed cleanups (see above)"
    echo "  3. Manually verify AWS console for any remaining resources"
else
    echo "  2. Verify AWS console shows no remaining resources"
fi
echo "════════════════════════════════════════════════════════════"
echo ""

# Exit with appropriate code
if [ ${#FAILED_CLEANUPS[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi


