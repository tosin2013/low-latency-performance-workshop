#!/bin/bash
# Destroy all workshop resources
#
# Usage:
#   ./destroy-workshop.sh [num_users] [user_prefix] [--force]
#
# Examples:
#   ./destroy-workshop.sh               # Auto-detect and destroy all users
#   ./destroy-workshop.sh 10            # Destroy users 1-10
#   ./destroy-workshop.sh 5 user        # Destroy user1-user5
#   ./destroy-workshop.sh 5 student     # Destroy student1-student5
#   ./destroy-workshop.sh 5 user --force # No confirmation prompt
#
# This script removes:
#   - SNO clusters from AWS
#   - ManagedClusters from RHACM
#   - User namespaces from hub
#   - Dev Spaces workspaces
#   - htpasswd users (optional)

set -e

NUM_USERS=${1:-0}
USER_PREFIX=${2:-""}
FORCE_MODE=false
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
SCRIPT_DIR="${WORKSHOP_DIR}/workshop-scripts"
HELPERS_DIR="${SCRIPT_DIR}/helpers"
OUTPUT_DIR="${HOME}/agnosticd-output"

# Check for --force flag
for arg in "$@"; do
    if [ "$arg" == "--force" ]; then
        FORCE_MODE=true
    fi
done

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     WORKSHOP CLEANUP                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Auto-detect user prefix and number if not specified
if [ -z "${USER_PREFIX}" ] || [ ${NUM_USERS} -eq 0 ]; then
    echo "Detecting deployed users..."
    
    # Check for user* deployments first (new default)
    DETECTED_USERS=$(ls -d ${OUTPUT_DIR}/workshop-user* 2>/dev/null | wc -l)
    if [ ${DETECTED_USERS} -gt 0 ]; then
        echo "Found ${DETECTED_USERS} 'user' deployment(s)"
        if [ -z "${USER_PREFIX}" ]; then
            USER_PREFIX="user"
        fi
        if [ ${NUM_USERS} -eq 0 ]; then
            NUM_USERS=${DETECTED_USERS}
        fi
    fi
    
    # Check for student* deployments (legacy)
    DETECTED_STUDENTS=$(ls -d ${OUTPUT_DIR}/workshop-student* 2>/dev/null | wc -l)
    if [ ${DETECTED_STUDENTS} -gt 0 ]; then
        echo "Found ${DETECTED_STUDENTS} 'student' deployment(s)"
        if [ -z "${USER_PREFIX}" ]; then
            USER_PREFIX="student"
        fi
        if [ ${NUM_USERS} -eq 0 ]; then
            NUM_USERS=${DETECTED_STUDENTS}
        fi
    fi
    
    # If still nothing found
    if [ ${NUM_USERS} -eq 0 ]; then
        echo "No deployments found in ${OUTPUT_DIR}"
        echo ""
        echo "Looking for: workshop-user* or workshop-student*"
        ls -la ${OUTPUT_DIR}/ 2>/dev/null || echo "  Directory empty or doesn't exist"
        echo ""
        read -p "Enter number of users to clean up (0 to abort): " NUM_USERS
        if [ ${NUM_USERS} -eq 0 ]; then
            echo "Aborted."
            exit 0
        fi
        read -p "Enter user prefix (user/student): " USER_PREFIX
    fi
fi

# Default to 'user' if still not set
USER_PREFIX=${USER_PREFIX:-user}

echo ""
echo "Configuration:"
echo "  User prefix: ${USER_PREFIX}"
echo "  Users to remove: ${USER_PREFIX}1 - ${USER_PREFIX}${NUM_USERS}"
echo "  Force mode: ${FORCE_MODE}"
echo ""

if [ "${FORCE_MODE}" != "true" ]; then
    echo "⚠️  WARNING: This will PERMANENTLY DELETE:"
    echo "    - ${NUM_USERS} SNO cluster(s) from AWS"
    echo "    - ManagedCluster resources from RHACM"
    echo "    - User namespaces (workshop-${USER_PREFIX}*)"
    echo "    - All associated AWS resources (VPCs, EC2, ELBs, etc.)"
    echo ""
    read -p "Type 'DELETE' to confirm: " CONFIRM
    if [ "${CONFIRM}" != "DELETE" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# ============================================
# Step 1: Remove from RHACM
# ============================================
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [1/4] Removing from RHACM                                 │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

if oc whoami &> /dev/null; then
    for i in $(seq 1 ${NUM_USERS}); do
        CLUSTER_NAME="workshop-${USER_PREFIX}${i}"
        if oc get managedcluster ${CLUSTER_NAME} &> /dev/null; then
            echo "  → Removing ManagedCluster: ${CLUSTER_NAME}"
            oc delete managedcluster ${CLUSTER_NAME} --wait=false 2>/dev/null || true
        fi
    done
    echo "  ✓ RHACM cleanup initiated"
else
    echo "  ⚠ Not logged into cluster - skipping RHACM cleanup"
fi

# ============================================
# Step 2: Destroy SNO Clusters (AWS)
# ============================================
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [2/4] Destroying SNO Clusters (AWS)                       │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

for i in $(seq 1 ${NUM_USERS}); do
    USERNAME="${USER_PREFIX}${i}"
    GUID="workshop-${USERNAME}"
    STACK_NAME="low-latency-workshop-sno-${GUID}"
    
    echo "  → Destroying ${GUID}..."
    
    # Method 1: Delete CloudFormation stack directly (fastest and most reliable)
    if aws cloudformation describe-stacks --stack-name ${STACK_NAME} &>/dev/null 2>&1; then
        echo "    Deleting CloudFormation stack: ${STACK_NAME}"
        aws cloudformation delete-stack --stack-name ${STACK_NAME}
        echo "    ✓ Stack deletion initiated"
    else
        echo "    ⚠ CloudFormation stack not found: ${STACK_NAME}"
    fi
done

# Wait for stack deletions to complete
echo ""
echo "  Waiting for CloudFormation stack deletions to complete..."
echo "  (This may take 5-10 minutes)"
echo ""

WAIT_TIMEOUT=600  # 10 minutes
WAIT_START=$(date +%s)

while true; do
    # Check if any stacks are still deleting
    DELETING_STACKS=$(aws cloudformation list-stacks \
        --stack-status-filter DELETE_IN_PROGRESS \
        --query "StackSummaries[?contains(StackName, 'workshop-${USER_PREFIX}')].StackName" \
        --output text 2>/dev/null)
    
    if [ -z "${DELETING_STACKS}" ]; then
        echo "  ✓ All CloudFormation stacks deleted"
        break
    fi
    
    ELAPSED=$(($(date +%s) - WAIT_START))
    if [ ${ELAPSED} -gt ${WAIT_TIMEOUT} ]; then
        echo "  ⚠ Timeout waiting for stack deletion"
        echo "    Still deleting: ${DELETING_STACKS}"
        break
    fi
    
    echo "    ... waiting (${ELAPSED}s elapsed) - deleting: ${DELETING_STACKS}"
    sleep 30
done

echo "  ✓ SNO cluster destruction complete"

# ============================================
# Step 2b: Cleanup Route53 DNS Records
# ============================================
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [2b/5] Cleaning Up Route53 DNS Records                    │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

# Get the subdomain suffix from secrets or detect from existing records
SUBDOMAIN_SUFFIX=$(grep "subdomain_base_suffix:" ~/secrets-ec2.yml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")

if [ -n "${SUBDOMAIN_SUFFIX}" ]; then
    # Remove leading dot if present
    SUBDOMAIN_CLEAN=$(echo ${SUBDOMAIN_SUFFIX} | sed 's/^\.//')
    
    # Find the hosted zone for this domain
    ZONE_ID=$(aws route53 list-hosted-zones \
        --query "HostedZones[?contains(Name, '${SUBDOMAIN_CLEAN}')].Id" \
        --output text 2>/dev/null | head -1 | sed 's|/hostedzone/||')
    
    if [ -n "${ZONE_ID}" ]; then
        echo "  Found hosted zone: ${ZONE_ID} for ${SUBDOMAIN_CLEAN}"
        
        for i in $(seq 1 ${NUM_USERS}); do
            GUID="workshop-${USER_PREFIX}${i}"
            
            # List and delete DNS records for this GUID
            echo "  → Checking DNS records for ${GUID}..."
            
            # Get all records containing the GUID
            RECORDS=$(aws route53 list-resource-record-sets \
                --hosted-zone-id ${ZONE_ID} \
                --query "ResourceRecordSets[?contains(Name, '${GUID}')]" \
                --output json 2>/dev/null)
            
            RECORD_COUNT=$(echo "${RECORDS}" | jq 'length' 2>/dev/null || echo "0")
            
            if [ "${RECORD_COUNT}" != "0" ] && [ "${RECORD_COUNT}" != "null" ]; then
                echo "    Found ${RECORD_COUNT} DNS records to delete"
                
                # Create batch delete request
                CHANGE_BATCH=$(echo "${RECORDS}" | jq '{
                    "Changes": [.[] | {
                        "Action": "DELETE",
                        "ResourceRecordSet": .
                    }]
                }' 2>/dev/null)
                
                if [ -n "${CHANGE_BATCH}" ] && [ "${CHANGE_BATCH}" != "null" ]; then
                    aws route53 change-resource-record-sets \
                        --hosted-zone-id ${ZONE_ID} \
                        --change-batch "${CHANGE_BATCH}" 2>/dev/null && \
                        echo "    ✓ DNS records deleted for ${GUID}" || \
                        echo "    ⚠ Failed to delete some DNS records"
                fi
            else
                echo "    No DNS records found for ${GUID}"
            fi
        done
    else
        echo "  ⚠ Could not find hosted zone for ${SUBDOMAIN_CLEAN}"
    fi
else
    echo "  ⚠ Could not determine subdomain suffix - skipping Route53 cleanup"
    echo "    (CloudFormation usually handles this automatically)"
fi

# ============================================
# Step 3: Remove Hub Resources
# ============================================
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [3/5] Removing Hub Resources                              │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

if oc whoami &> /dev/null; then
    for i in $(seq 1 ${NUM_USERS}); do
        NAMESPACE="workshop-${USER_PREFIX}${i}"
        if oc get namespace ${NAMESPACE} &> /dev/null; then
            echo "  → Removing namespace: ${NAMESPACE}"
            oc delete namespace ${NAMESPACE} --wait=false 2>/dev/null || true
        fi
    done
    echo "  ✓ Namespace cleanup initiated"
else
    echo "  ⚠ Not logged into cluster - skipping hub cleanup"
fi

# ============================================
# Step 4: Cleanup Local Files
# ============================================
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  [4/5] Cleaning Up Local Files                             │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""

for i in $(seq 1 ${NUM_USERS}); do
    GUID="workshop-${USER_PREFIX}${i}"
    if [ -d "${OUTPUT_DIR}/${GUID}" ]; then
        echo "  → Removing: ${OUTPUT_DIR}/${GUID}"
        rm -rf "${OUTPUT_DIR}/${GUID}"
    fi
done

# Remove credentials file
if [ -f "${WORKSHOP_DIR}/workshop-credentials.yaml" ]; then
    echo "  → Removing credentials file"
    rm -f "${WORKSHOP_DIR}/workshop-credentials.yaml"
fi

echo "  ✓ Local cleanup complete"

# ============================================
# Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     CLEANUP COMPLETE                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Removed:"
echo "  - ${NUM_USERS} SNO cluster(s) (${USER_PREFIX}1-${USER_PREFIX}${NUM_USERS})"
echo "  - ${NUM_USERS} ManagedCluster resource(s)"
echo "  - ${NUM_USERS} namespace(s)"
echo "  - Local credential files"
echo ""
echo "Note: AWS resource cleanup runs asynchronously."
echo "      Check AWS console to verify all resources are removed."
echo ""
echo "Verification commands:"
echo "  oc get managedclusters -l workshop=low-latency"
echo "  oc get namespaces -l workshop=low-latency"
echo "  aws ec2 describe-instances --filters 'Name=tag:workshop,Values=low-latency'"
echo "  aws cloudformation list-stacks --stack-status-filter DELETE_IN_PROGRESS"
echo ""
