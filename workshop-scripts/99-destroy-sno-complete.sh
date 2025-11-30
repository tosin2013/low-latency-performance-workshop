#!/bin/bash
# COMPLETE cleanup of SNO deployment including IPI-created infrastructure

set -e

STUDENT_NAME=${1:-student1}
DEPLOYMENT_MODE=${2:-rhpds}
GUID="test-${STUDENT_NAME}"
CLUSTER_NAME="workshop-${STUDENT_NAME}"
AWS_REGION="us-east-2"

echo "════════════════════════════════════════════════════════════"
echo " COMPLETE SNO CLEANUP (Including IPI Infrastructure)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: ${GUID}"
echo "Region: ${AWS_REGION}"
echo ""
echo "⚠️  This will DELETE:"
echo "  - SNO cluster (via openshift-install destroy)"
echo "  - Bastion VPC and EC2"
echo "  - All CloudFormation stacks"
echo "  - Route53 DNS records
  - SSH keys"
echo "  - Local files"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting complete cleanup..."
echo ""

# ============================================================
# STEP 1: Destroy SNO Cluster using openshift-install
# ============================================================
echo "[1/9] Destroying SNO cluster via openshift-install..."
echo ""

# Check if bastion is still up
BASTION_IP=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters \
    "Name=tag:guid,Values=${GUID}" \
    "Name=tag:AnsibleGroup,Values=bastions" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null || echo "")

SSH_KEY="${HOME}/agnosticd-output/${GUID}/ssh_provision_${GUID}"

if [ -n "$BASTION_IP" ] && [ "$BASTION_IP" != "None" ] && [ -f "$SSH_KEY" ]; then
    echo "  → Bastion found at ${BASTION_IP}"
    echo "  → Running 'openshift-install destroy cluster' on bastion..."
    echo ""
    
    # Run destroy on bastion
    ssh -i "$SSH_KEY" \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=10 \
      ec2-user@${BASTION_IP} << 'EOSSH' || echo "  ⚠️  Destroy command failed or bastion unavailable"

# Find the cluster directory
CLUSTER_DIR=$(ls -d ~/test-* 2>/dev/null | head -1)

if [ -d "$CLUSTER_DIR" ]; then
    echo "Found cluster directory: $CLUSTER_DIR"
    cd "$CLUSTER_DIR"
    
    # Run destroy
    echo "Running: openshift-install destroy cluster --log-level=debug"
    /usr/local/bin/openshift-install destroy cluster --dir="$CLUSTER_DIR" --log-level=debug || true
    
    echo "✓ OpenShift IPI destroy completed"
else
    echo "⚠️  No cluster directory found - cluster may already be destroyed"
fi
EOSSH

    echo ""
    echo "  ✓ SNO cluster destruction initiated"
    echo "  → Waiting 2 minutes for resources to terminate..."
    sleep 120
else
    echo "  ⚠️  Bastion not accessible - will clean up AWS resources manually"
fi

# ============================================================
# STEP 2: Find and Delete SNO Cluster Infrastructure
# ============================================================
echo ""
echo "[2/9] Finding SNO cluster infrastructure..."

# Find the cluster infra ID
INFRA_ID=$(aws ec2 describe-vpcs \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" \
  --query 'Vpcs[*].Tags[?Key==`Name`].Value | [0][0]' \
  --output text 2>/dev/null | grep -oP '.*-\K\w+(?=-vpc)' || echo "")

if [ -n "$INFRA_ID" ]; then
    echo "  → Found SNO infra ID: ${INFRA_ID}"
    
    # Terminate EC2 instances
    echo "  → Terminating SNO cluster EC2 instances..."
    SNO_INSTANCES=$(aws ec2 describe-instances \
      --region ${AWS_REGION} \
      --filters "Name=tag:kubernetes.io/cluster/${GUID}-${INFRA_ID},Values=owned" \
                "Name=instance-state-name,Values=running,stopped,stopping" \
      --query 'Reservations[*].Instances[*].InstanceId' \
      --output text)
    
    if [ -n "$SNO_INSTANCES" ]; then
        aws ec2 terminate-instances --region ${AWS_REGION} --instance-ids $SNO_INSTANCES
        echo "  ✓ Terminated SNO instances: $SNO_INSTANCES"
    else
        echo "  → No SNO instances found"
    fi
    
    # Delete load balancers
    echo "  → Deleting load balancers..."
    LBS=$(aws elbv2 describe-load-balancers \
      --region ${AWS_REGION} \
      --query "LoadBalancers[?contains(LoadBalancerName, '${INFRA_ID}')].LoadBalancerArn" \
      --output text 2>/dev/null || echo "")
    
    for LB in $LBS; do
        echo "    → Deleting LB: $LB"
        aws elbv2 delete-load-balancer --region ${AWS_REGION} --load-balancer-arn "$LB" || true
    done
    
    # Wait for LBs to delete
    if [ -n "$LBS" ]; then
        echo "  → Waiting 30s for load balancers to delete..."
        sleep 30
    fi
    
    # Delete target groups
    echo "  → Deleting target groups..."
    TGS=$(aws elbv2 describe-target-groups \
      --region ${AWS_REGION} \
      --query "TargetGroups[?contains(TargetGroupName, '${INFRA_ID}')].TargetGroupArn" \
      --output text 2>/dev/null || echo "")
    
    for TG in $TGS; do
        echo "    → Deleting TG: $TG"
        aws elbv2 delete-target-group --region ${AWS_REGION} --target-group-arn "$TG" || true
    done
else
    echo "  → No SNO cluster infra ID found (may already be cleaned up)"
fi

# ============================================================
# STEP 3: Clean up Route53 DNS Records
# ============================================================
echo ""
echo "[3/9] Cleaning up Route53 DNS records..."

# Find parent hosted zone
PARENT_ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`sandbox862.opentlc.com.`].Id' \
  --output text 2>/dev/null | cut -d'/' -f3)

if [ -n "$PARENT_ZONE_ID" ]; then
    echo "  → Found parent zone: $PARENT_ZONE_ID"
    
    # Get all DNS records for this GUID
    RECORDS=$(aws route53 list-resource-record-sets \
      --hosted-zone-id "$PARENT_ZONE_ID" \
      --query "ResourceRecordSets[?contains(Name, \`${GUID}\`)]" \
      --output json 2>/dev/null)
    
    RECORD_COUNT=$(echo "$RECORDS" | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$RECORD_COUNT" -gt 0 ]; then
        echo "  → Found $RECORD_COUNT DNS record(s) to delete"
        
        # Delete each record
        echo "$RECORDS" | jq -c '.[]' 2>/dev/null | while read -r record; do
            RECORD_NAME=$(echo "$record" | jq -r '.Name')
            RECORD_TYPE=$(echo "$record" | jq -r '.Type')
            
            # Skip SOA records
            if [ "$RECORD_TYPE" == "SOA" ]; then
                continue
            fi
            
            echo "     → Deleting $RECORD_TYPE: $RECORD_NAME"
            
            # Create and execute deletion
            CHANGE_BATCH=$(cat <<BATCH
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": $record
  }]
}
BATCH
)
            
            aws route53 change-resource-record-sets \
              --hosted-zone-id "$PARENT_ZONE_ID" \
              --change-batch "$CHANGE_BATCH" \
              --output text &>/dev/null && echo "        ✓ Deleted" || echo "        ✗ Failed"
        done
        
        echo "  ✓ DNS cleanup complete"
    else
        echo "  → No DNS records found"
    fi
else
    echo "  → Parent hosted zone not found"
fi

# ============================================================
# STEP 4: Remove from RHACM
# ============================================================
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo ""
    echo "[4/9] Removing ManagedCluster from RHACM..."
    if oc get managedcluster ${CLUSTER_NAME} &>/dev/null; then
        oc delete managedcluster ${CLUSTER_NAME} --wait=false || echo "  ⚠️  Failed to delete"
        echo "  ✓ ManagedCluster ${CLUSTER_NAME} deleted"
    else
        echo "  → ManagedCluster not found"
    fi
else
    echo ""
    echo "[4/9] Skipping RHACM cleanup (standalone mode)"
fi

# ============================================================
# STEP 5: Delete ALL CloudFormation Stacks with GUID
# ============================================================
echo ""
echo "[5/9] Deleting CloudFormation stacks..."

# Find ALL stacks with this GUID
STACKS=$(aws cloudformation describe-stacks \
  --region ${AWS_REGION} \
  --query "Stacks[?Tags[?Key=='guid' && Value=='${GUID}']].StackName" \
  --output text 2>/dev/null || echo "")

if [ -n "$STACKS" ]; then
    for STACK in $STACKS; do
        echo "  → Deleting stack: ${STACK}..."
        aws cloudformation delete-stack \
            --region ${AWS_REGION} \
            --stack-name ${STACK}
        
        echo "  → Waiting for stack deletion..."
        aws cloudformation wait stack-delete-complete \
            --region ${AWS_REGION} \
            --stack-name ${STACK} 2>&1 | head -5 || true
        
        echo "  ✓ Stack ${STACK} deleted"
    done
else
    echo "  → No CloudFormation stacks found with GUID: ${GUID}"
fi

# ============================================================
# STEP 5: Clean Up Orphaned EC2 Instances
# ============================================================
echo ""
echo "[6/9] Checking for orphaned EC2 instances..."

ORPHANED=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" \
            "Name=instance-state-name,Values=running,stopped,stopping" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text 2>/dev/null)

if [ -n "${ORPHANED}" ]; then
    echo "  → Terminating: ${ORPHANED}"
    aws ec2 terminate-instances --region ${AWS_REGION} --instance-ids ${ORPHANED}
    echo "  ✓ Orphaned instances terminated"
else
    echo "  → No orphaned instances"
fi

# ============================================================
# STEP 6: Delete VPCs and Dependencies (with retries)
# ============================================================
echo ""
echo "[7/9] Cleaning up VPCs and network resources..."

VPCS=$(aws ec2 describe-vpcs \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" \
  --query 'Vpcs[*].VpcId' \
  --output text)

for VPC in $VPCS; do
    echo "  → Cleaning up VPC: ${VPC}"
    
    # Delete NAT gateways first (they take time to delete)
    echo "    [6.1] NAT Gateways..."
    NATS=$(aws ec2 describe-nat-gateways \
      --region ${AWS_REGION} \
      --filter "Name=vpc-id,Values=${VPC}" "Name=state,Values=available,pending,deleting" \
      --query 'NatGateways[*].NatGatewayId' \
      --output text)
    
    for NAT in $NATS; do
        echo "      → Deleting NAT gateway: $NAT"
        aws ec2 delete-nat-gateway --region ${AWS_REGION} --nat-gateway-id $NAT || true
    done
    
    # Wait for NATs to delete
    if [ -n "$NATS" ]; then
        echo "      → Waiting 60s for NAT gateways to delete..."
        sleep 60
    fi
    
    # Delete VPC Endpoints
    echo "    [6.2] VPC Endpoints..."
    VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
      --region ${AWS_REGION} \
      --filters "Name=vpc-id,Values=${VPC}" \
      --query 'VpcEndpoints[*].VpcEndpointId' \
      --output text 2>/dev/null || echo "")
    
    for ENDPOINT in $VPC_ENDPOINTS; do
        echo "      → Deleting VPC endpoint: $ENDPOINT"
        aws ec2 delete-vpc-endpoints --region ${AWS_REGION} --vpc-endpoint-ids $ENDPOINT || true
    done
    
    # Delete Network Interfaces (ENIs)
    echo "    [6.3] Network Interfaces..."
    ENIS=$(aws ec2 describe-network-interfaces \
      --region ${AWS_REGION} \
      --filters "Name=vpc-id,Values=${VPC}" \
      --query 'NetworkInterfaces[*].NetworkInterfaceId' \
      --output text 2>/dev/null || echo "")
    
    for ENI in $ENIS; do
        echo "      → Deleting network interface: $ENI"
        # First try to detach
        aws ec2 detach-network-interface --region ${AWS_REGION} --attachment-id \
          $(aws ec2 describe-network-interfaces --region ${AWS_REGION} \
            --network-interface-ids $ENI \
            --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
            --output text 2>/dev/null) 2>/dev/null || true
        sleep 2
        # Then delete
        aws ec2 delete-network-interface --region ${AWS_REGION} --network-interface-id $ENI 2>/dev/null || true
    done
    
    # Delete Internet Gateways
    echo "    [6.4] Internet Gateways..."
    IGWS=$(aws ec2 describe-internet-gateways \
      --region ${AWS_REGION} \
      --filters "Name=attachment.vpc-id,Values=${VPC}" \
      --query 'InternetGateways[*].InternetGatewayId' \
      --output text)
    
    for IGW in $IGWS; do
        echo "      → Detaching IGW: $IGW"
        aws ec2 detach-internet-gateway --region ${AWS_REGION} --internet-gateway-id $IGW --vpc-id $VPC 2>/dev/null || true
        sleep 2
        echo "      → Deleting IGW: $IGW"
        aws ec2 delete-internet-gateway --region ${AWS_REGION} --internet-gateway-id $IGW 2>/dev/null || true
    done
    
    # Delete Subnets
    echo "    [6.5] Subnets..."
    SUBNETS=$(aws ec2 describe-subnets \
      --region ${AWS_REGION} \
      --filters "Name=vpc-id,Values=${VPC}" \
      --query 'Subnets[*].SubnetId' \
      --output text)
    
    for SUBNET in $SUBNETS; do
        echo "      → Deleting subnet: $SUBNET"
        aws ec2 delete-subnet --region ${AWS_REGION} --subnet-id $SUBNET 2>/dev/null || true
    done
    
    # Delete Security Groups (except default) - with retries
    echo "    [6.6] Security Groups..."
    for attempt in {1..3}; do
        SGS=$(aws ec2 describe-security-groups \
          --region ${AWS_REGION} \
          --filters "Name=vpc-id,Values=${VPC}" \
          --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
          --output text 2>/dev/null || echo "")
        
        if [ -z "$SGS" ]; then
            echo "      ✓ All security groups deleted"
            break
        fi
        
        echo "      → Attempt $attempt: Deleting security groups..."
        for SG in $SGS; do
            aws ec2 delete-security-group --region ${AWS_REGION} --group-id $SG 2>/dev/null || true
        done
        
        [ $attempt -lt 3 ] && sleep 5
    done
    
    # Delete Route Tables (except main)
    echo "    [6.7] Route Tables..."
    RTS=$(aws ec2 describe-route-tables \
      --region ${AWS_REGION} \
      --filters "Name=vpc-id,Values=${VPC}" \
      --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
      --output text 2>/dev/null || echo "")
    
    for RT in $RTS; do
        echo "      → Deleting route table: $RT"
        # Disassociate first
        ASSOC=$(aws ec2 describe-route-tables \
          --region ${AWS_REGION} \
          --route-table-ids $RT \
          --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
          --output text 2>/dev/null || echo "")
        
        for ASSOC_ID in $ASSOC; do
            aws ec2 disassociate-route-table --region ${AWS_REGION} --association-id $ASSOC_ID 2>/dev/null || true
        done
        
        aws ec2 delete-route-table --region ${AWS_REGION} --route-table-id $RT 2>/dev/null || true
    done
    
    # Delete VPC with retries
    echo "    [6.8] VPC Deletion (with retries)..."
    VPC_DELETED=false
    
    for attempt in {1..5}; do
        echo "      → Attempt $attempt to delete VPC..."
        
        if aws ec2 delete-vpc --region ${AWS_REGION} --vpc-id $VPC 2>/dev/null; then
            echo "      ✓ VPC deleted successfully!"
            VPC_DELETED=true
            break
        else
            if [ $attempt -lt 5 ]; then
                echo "      ⚠️  VPC deletion failed, retrying in 10s..."
                
                # Re-check for remaining dependencies
                echo "      → Checking for remaining dependencies..."
                
                # Check for remaining subnets
                REMAINING_SUBNETS=$(aws ec2 describe-subnets \
                  --region ${AWS_REGION} \
                  --filters "Name=vpc-id,Values=${VPC}" \
                  --query 'Subnets[*].SubnetId' \
                  --output text 2>/dev/null || echo "")
                
                if [ -n "$REMAINING_SUBNETS" ]; then
                    echo "      → Found remaining subnets, deleting: $REMAINING_SUBNETS"
                    for SUBNET in $REMAINING_SUBNETS; do
                        aws ec2 delete-subnet --region ${AWS_REGION} --subnet-id $SUBNET 2>/dev/null || true
                    done
                fi
                
                # Check for remaining IGWs
                REMAINING_IGWS=$(aws ec2 describe-internet-gateways \
                  --region ${AWS_REGION} \
                  --filters "Name=attachment.vpc-id,Values=${VPC}" \
                  --query 'InternetGateways[*].InternetGatewayId' \
                  --output text 2>/dev/null || echo "")
                
                if [ -n "$REMAINING_IGWS" ]; then
                    echo "      → Found remaining IGWs, deleting: $REMAINING_IGWS"
                    for IGW in $REMAINING_IGWS; do
                        aws ec2 detach-internet-gateway --region ${AWS_REGION} --internet-gateway-id $IGW --vpc-id $VPC 2>/dev/null || true
                        aws ec2 delete-internet-gateway --region ${AWS_REGION} --internet-gateway-id $IGW 2>/dev/null || true
                    done
                fi
                
                # Check for remaining route tables
                REMAINING_RTS=$(aws ec2 describe-route-tables \
                  --region ${AWS_REGION} \
                  --filters "Name=vpc-id,Values=${VPC}" \
                  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
                  --output text 2>/dev/null || echo "")
                
                if [ -n "$REMAINING_RTS" ]; then
                    echo "      → Found remaining route tables, deleting: $REMAINING_RTS"
                    for RT in $REMAINING_RTS; do
                        aws ec2 delete-route-table --region ${AWS_REGION} --route-table-id $RT 2>/dev/null || true
                    done
                fi
                
                sleep 10
            fi
        fi
    done
    
    if [ "$VPC_DELETED" = false ]; then
        echo "      ⚠️  VPC ${VPC} could not be deleted after 5 attempts"
        echo "      → Manual cleanup may be required"
    fi
    
    echo ""
done

# ============================================================
# STEP 7: Delete SSH Key Pair
# ============================================================
echo ""
echo "[8/9] Deleting SSH key pair..."

KEY_NAME="ssh_provision_${GUID}"
if aws ec2 describe-key-pairs --region ${AWS_REGION} --key-names ${KEY_NAME} &>/dev/null; then
    aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${KEY_NAME}
    echo "  ✓ SSH key ${KEY_NAME} deleted"
else
    echo "  → SSH key not found"
fi

# ============================================================
# STEP 8: Clean Up Local Files
# ============================================================
echo ""
echo "[9/9] Cleaning up local files..."

OUTPUT_DIR=~/agnosticd-output/${GUID}
if [ -d "${OUTPUT_DIR}" ]; then
    rm -rf ${OUTPUT_DIR}
    echo "  ✓ Removed ${OUTPUT_DIR}"
else
    echo "  → Output directory not found"
fi

# Clean up template files
TEMPLATES=$(find /tmp -name "*${GUID}*" -name "*.ec2_cloud_template" 2>/dev/null || echo "")
if [ -n "$TEMPLATES" ]; then
    rm -f $TEMPLATES
    echo "  ✓ Template files removed"
fi

# ============================================================
# FINAL VERIFICATION
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════"
echo " Cleanup Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Verification:"
echo ""

# Check stacks
REMAINING_STACKS=$(aws cloudformation describe-stacks \
  --region ${AWS_REGION} \
  --query "Stacks[?Tags[?Key=='guid' && Value=='${GUID}']].StackName" \
  --output text 2>/dev/null || echo "")

if [ -z "$REMAINING_STACKS" ]; then
    echo "  ✓ No CloudFormation stacks"
else
    echo "  ⚠️  Remaining stacks: $REMAINING_STACKS"
fi

# Check instances
REMAINING_INSTANCES=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" \
            "Name=instance-state-name,Values=running,pending,stopped,stopping" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -z "$REMAINING_INSTANCES" ]; then
    echo "  ✓ No EC2 instances"
else
    echo "  ⚠️  Remaining instances: $REMAINING_INSTANCES"
fi

# Check VPCs
REMAINING_VPCS=$(aws ec2 describe-vpcs \
  --region ${AWS_REGION} \
  --filters "Name=tag:guid,Values=${GUID}" \
  --query 'Vpcs[*].VpcId' \
  --output text 2>/dev/null || echo "")

if [ -z "$REMAINING_VPCS" ]; then
    echo "  ✓ No VPCs"
else
    echo "  ⚠️  Remaining VPCs: $REMAINING_VPCS"
    echo "     (May have dependencies - check manually)"
fi

echo ""
echo "✅ Cleanup complete for ${STUDENT_NAME}"
echo ""

