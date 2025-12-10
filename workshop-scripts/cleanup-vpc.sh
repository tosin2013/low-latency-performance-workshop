#!/bin/bash
# Advanced VPC Cleanup Script
# Deletes all AWS resources associated with a VPC
#
# Usage:
#   ./cleanup-vpc.sh <vpc-id> [--force]
#
# Examples:
#   ./cleanup-vpc.sh vpc-0123456789abcdef0           # Interactive mode
#   ./cleanup-vpc.sh vpc-0123456789abcdef0 --force   # No confirmation
#
# This script will delete:
#   - EC2 instances
#   - NAT Gateways
#   - Internet Gateways
#   - Elastic IPs
#   - Load Balancers (ELB/ALB/NLB)
#   - Security Groups
#   - Network Interfaces
#   - Subnets
#   - Route Tables
#   - VPC Endpoints
#   - VPC Peering Connections
#   - Route53 records (if GUID detected)
#   - CloudFormation stacks (if detected)
#   - The VPC itself
#
# WARNING: This is destructive and cannot be undone!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
VPC_ID=$1
FORCE_DELETE=false

if [ "$2" == "--force" ]; then
    FORCE_DELETE=true
fi

# Validate VPC ID
if [ -z "${VPC_ID}" ]; then
    echo -e "${RED}Error: VPC ID required${NC}"
    echo ""
    echo "Usage: $0 <vpc-id> [--force]"
    echo ""
    echo "Examples:"
    echo "  $0 vpc-0123456789abcdef0"
    echo "  $0 vpc-0123456789abcdef0 --force"
    echo ""
    echo "To find VPC IDs:"
    echo "  aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==\`Name\`].Value|[0]]' --output table"
    exit 1
fi

if [[ ! "${VPC_ID}" =~ ^vpc-[a-f0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid VPC ID format. Expected: vpc-xxxxxxxxx${NC}"
    exit 1
fi

# Get AWS region
REGION=$(aws configure get region 2>/dev/null || echo "us-east-2")
if [ -f ~/secrets-ec2.yml ]; then
    REGION=$(grep "aws_region:" ~/secrets-ec2.yml | awk '{print $2}' || echo "${REGION}")
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     ADVANCED VPC CLEANUP SCRIPT                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "VPC ID:  ${BLUE}${VPC_ID}${NC}"
echo -e "Region:  ${BLUE}${REGION}${NC}"
echo ""

# Get VPC info
echo "[1/15] Getting VPC information..."
VPC_INFO=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --region ${REGION} 2>/dev/null || echo "")

if [ -z "${VPC_INFO}" ]; then
    echo -e "${RED}Error: VPC ${VPC_ID} not found in region ${REGION}${NC}"
    exit 1
fi

VPC_NAME=$(echo "${VPC_INFO}" | jq -r '.Vpcs[0].Tags[]? | select(.Key=="Name") | .Value // "unnamed"')
VPC_CIDR=$(echo "${VPC_INFO}" | jq -r '.Vpcs[0].CidrBlock')
GUID=$(echo "${VPC_INFO}" | jq -r '.Vpcs[0].Tags[]? | select(.Key=="guid") | .Value // empty')

echo -e "  VPC Name: ${YELLOW}${VPC_NAME}${NC}"
echo -e "  VPC CIDR: ${VPC_CIDR}"
if [ -n "${GUID}" ]; then
    echo -e "  GUID:     ${YELLOW}${GUID}${NC}"
fi
echo ""

# Confirmation
if [ "${FORCE_DELETE}" != "true" ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  WARNING: This will DELETE ALL resources in this VPC!     ║${NC}"
    echo -e "${RED}║  This action CANNOT be undone!                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -n "Type 'DELETE' to confirm: "
    read CONFIRM
    if [ "${CONFIRM}" != "DELETE" ]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Track what we delete
declare -a DELETED_RESOURCES

# Function to log deletion
log_delete() {
    local resource_type=$1
    local resource_id=$2
    echo -e "  ${GREEN}✓${NC} Deleted ${resource_type}: ${resource_id}"
    DELETED_RESOURCES+=("${resource_type}:${resource_id}")
}

log_skip() {
    local resource_type=$1
    local reason=$2
    echo -e "  ${YELLOW}⚠${NC} Skipped ${resource_type}: ${reason}"
}

log_error() {
    local resource_type=$1
    local resource_id=$2
    local error=$3
    echo -e "  ${RED}✗${NC} Failed to delete ${resource_type} ${resource_id}: ${error}"
}

# ============================================================
# 2. Terminate EC2 Instances
# ============================================================
echo "[2/15] Terminating EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")

if [ -n "${INSTANCES}" ] && [ "${INSTANCES}" != "None" ]; then
    for INSTANCE_ID in ${INSTANCES}; do
        echo "  Terminating instance ${INSTANCE_ID}..."
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region ${REGION} 2>/dev/null && \
            log_delete "EC2 Instance" "${INSTANCE_ID}" || \
            log_error "EC2 Instance" "${INSTANCE_ID}" "termination failed"
    done
    
    echo "  Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids ${INSTANCES} --region ${REGION} 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} All instances terminated"
else
    log_skip "EC2 Instances" "none found"
fi

# ============================================================
# 3. Delete NAT Gateways
# ============================================================
echo "[3/15] Deleting NAT Gateways..."
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways \
    --region ${REGION} \
    --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available,pending" \
    --query 'NatGateways[*].NatGatewayId' \
    --output text 2>/dev/null || echo "")

if [ -n "${NAT_GATEWAYS}" ] && [ "${NAT_GATEWAYS}" != "None" ]; then
    for NAT_ID in ${NAT_GATEWAYS}; do
        aws ec2 delete-nat-gateway --nat-gateway-id ${NAT_ID} --region ${REGION} 2>/dev/null && \
            log_delete "NAT Gateway" "${NAT_ID}" || \
            log_error "NAT Gateway" "${NAT_ID}" "deletion failed"
    done
    
    echo "  Waiting for NAT gateways to delete (this may take a few minutes)..."
    for NAT_ID in ${NAT_GATEWAYS}; do
        while true; do
            STATE=$(aws ec2 describe-nat-gateways --nat-gateway-ids ${NAT_ID} --region ${REGION} \
                --query 'NatGateways[0].State' --output text 2>/dev/null || echo "deleted")
            if [ "${STATE}" == "deleted" ] || [ "${STATE}" == "None" ]; then
                break
            fi
            sleep 10
        done
    done
    echo -e "  ${GREEN}✓${NC} All NAT gateways deleted"
else
    log_skip "NAT Gateways" "none found"
fi

# ============================================================
# 4. Delete Load Balancers (ELB, ALB, NLB)
# ============================================================
echo "[4/15] Deleting Load Balancers..."

# Classic ELBs
CLASSIC_ELBS=$(aws elb describe-load-balancers --region ${REGION} \
    --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" \
    --output text 2>/dev/null || echo "")

if [ -n "${CLASSIC_ELBS}" ] && [ "${CLASSIC_ELBS}" != "None" ]; then
    for ELB_NAME in ${CLASSIC_ELBS}; do
        aws elb delete-load-balancer --load-balancer-name ${ELB_NAME} --region ${REGION} 2>/dev/null && \
            log_delete "Classic ELB" "${ELB_NAME}" || \
            log_error "Classic ELB" "${ELB_NAME}" "deletion failed"
    done
fi

# ALB/NLB
MODERN_LBS=$(aws elbv2 describe-load-balancers --region ${REGION} \
    --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" \
    --output text 2>/dev/null || echo "")

if [ -n "${MODERN_LBS}" ] && [ "${MODERN_LBS}" != "None" ]; then
    for LB_ARN in ${MODERN_LBS}; do
        LB_NAME=$(echo ${LB_ARN} | awk -F'/' '{print $3}')
        aws elbv2 delete-load-balancer --load-balancer-arn ${LB_ARN} --region ${REGION} 2>/dev/null && \
            log_delete "ALB/NLB" "${LB_NAME}" || \
            log_error "ALB/NLB" "${LB_NAME}" "deletion failed"
    done
    
    echo "  Waiting for load balancers to delete..."
    sleep 30
fi

if [ -z "${CLASSIC_ELBS}" ] && [ -z "${MODERN_LBS}" ]; then
    log_skip "Load Balancers" "none found"
fi

# ============================================================
# 5. Delete VPC Endpoints
# ============================================================
echo "[5/15] Deleting VPC Endpoints..."
VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'VpcEndpoints[*].VpcEndpointId' \
    --output text 2>/dev/null || echo "")

if [ -n "${VPC_ENDPOINTS}" ] && [ "${VPC_ENDPOINTS}" != "None" ]; then
    for ENDPOINT_ID in ${VPC_ENDPOINTS}; do
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids ${ENDPOINT_ID} --region ${REGION} 2>/dev/null && \
            log_delete "VPC Endpoint" "${ENDPOINT_ID}" || \
            log_error "VPC Endpoint" "${ENDPOINT_ID}" "deletion failed"
    done
else
    log_skip "VPC Endpoints" "none found"
fi

# ============================================================
# 6. Delete VPC Peering Connections
# ============================================================
echo "[6/15] Deleting VPC Peering Connections..."
PEERING_CONNECTIONS=$(aws ec2 describe-vpc-peering-connections \
    --region ${REGION} \
    --filters "Name=requester-vpc-info.vpc-id,Values=${VPC_ID}" \
    --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' \
    --output text 2>/dev/null || echo "")

PEERING_CONNECTIONS2=$(aws ec2 describe-vpc-peering-connections \
    --region ${REGION} \
    --filters "Name=accepter-vpc-info.vpc-id,Values=${VPC_ID}" \
    --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' \
    --output text 2>/dev/null || echo "")

ALL_PEERINGS="${PEERING_CONNECTIONS} ${PEERING_CONNECTIONS2}"
ALL_PEERINGS=$(echo ${ALL_PEERINGS} | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -n "$(echo ${ALL_PEERINGS} | tr -d ' ')" ]; then
    for PEERING_ID in ${ALL_PEERINGS}; do
        [ -z "${PEERING_ID}" ] && continue
        aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id ${PEERING_ID} --region ${REGION} 2>/dev/null && \
            log_delete "VPC Peering" "${PEERING_ID}" || \
            log_error "VPC Peering" "${PEERING_ID}" "deletion failed"
    done
else
    log_skip "VPC Peering" "none found"
fi

# ============================================================
# 7. Detach and Delete Internet Gateways
# ============================================================
echo "[7/15] Deleting Internet Gateways..."
IGW_IDS=$(aws ec2 describe-internet-gateways \
    --region ${REGION} \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[*].InternetGatewayId' \
    --output text 2>/dev/null || echo "")

if [ -n "${IGW_IDS}" ] && [ "${IGW_IDS}" != "None" ]; then
    for IGW_ID in ${IGW_IDS}; do
        echo "  Detaching ${IGW_ID} from VPC..."
        aws ec2 detach-internet-gateway --internet-gateway-id ${IGW_ID} --vpc-id ${VPC_ID} --region ${REGION} 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id ${IGW_ID} --region ${REGION} 2>/dev/null && \
            log_delete "Internet Gateway" "${IGW_ID}" || \
            log_error "Internet Gateway" "${IGW_ID}" "deletion failed"
    done
else
    log_skip "Internet Gateways" "none found"
fi

# ============================================================
# 8. Release Elastic IPs
# ============================================================
echo "[8/15] Releasing Elastic IPs..."

# Get EIPs associated with this VPC's network interfaces
ENI_IDS=$(aws ec2 describe-network-interfaces \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' \
    --output text 2>/dev/null || echo "")

if [ -n "${ENI_IDS}" ] && [ "${ENI_IDS}" != "None" ]; then
    for ENI_ID in ${ENI_IDS}; do
        ALLOC_ID=$(aws ec2 describe-addresses \
            --region ${REGION} \
            --filters "Name=network-interface-id,Values=${ENI_ID}" \
            --query 'Addresses[0].AllocationId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "${ALLOC_ID}" ] && [ "${ALLOC_ID}" != "None" ]; then
            aws ec2 release-address --allocation-id ${ALLOC_ID} --region ${REGION} 2>/dev/null && \
                log_delete "Elastic IP" "${ALLOC_ID}" || \
                log_error "Elastic IP" "${ALLOC_ID}" "release failed"
        fi
    done
fi

# Also check by GUID tag if available
if [ -n "${GUID}" ]; then
    TAGGED_EIPS=$(aws ec2 describe-addresses \
        --region ${REGION} \
        --filters "Name=tag:guid,Values=${GUID}" \
        --query 'Addresses[*].AllocationId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${TAGGED_EIPS}" ] && [ "${TAGGED_EIPS}" != "None" ]; then
        for ALLOC_ID in ${TAGGED_EIPS}; do
            aws ec2 release-address --allocation-id ${ALLOC_ID} --region ${REGION} 2>/dev/null && \
                log_delete "Elastic IP (tagged)" "${ALLOC_ID}" || true
        done
    fi
fi

# ============================================================
# 9. Delete Network Interfaces
# ============================================================
echo "[9/15] Deleting Network Interfaces..."
NETWORK_INTERFACES=$(aws ec2 describe-network-interfaces \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Attachment.AttachmentId]' \
    --output text 2>/dev/null || echo "")

if [ -n "${NETWORK_INTERFACES}" ] && [ "${NETWORK_INTERFACES}" != "None" ]; then
    echo "${NETWORK_INTERFACES}" | while read ENI_ID ATTACH_ID; do
        [ -z "${ENI_ID}" ] && continue
        
        # Detach if attached
        if [ -n "${ATTACH_ID}" ] && [ "${ATTACH_ID}" != "None" ]; then
            aws ec2 detach-network-interface --attachment-id ${ATTACH_ID} --force --region ${REGION} 2>/dev/null || true
            sleep 2
        fi
        
        # Delete ENI
        aws ec2 delete-network-interface --network-interface-id ${ENI_ID} --region ${REGION} 2>/dev/null && \
            log_delete "Network Interface" "${ENI_ID}" || \
            log_error "Network Interface" "${ENI_ID}" "deletion failed (may be managed)"
    done
else
    log_skip "Network Interfaces" "none found"
fi

# ============================================================
# 10. Delete Security Groups
# ============================================================
echo "[10/15] Deleting Security Groups..."

# First, remove all ingress/egress rules that reference other SGs
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[*].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -n "${SECURITY_GROUPS}" ] && [ "${SECURITY_GROUPS}" != "None" ]; then
    echo "  Removing inter-SG references..."
    for SG_ID in ${SECURITY_GROUPS}; do
        # Get and remove ingress rules
        aws ec2 describe-security-groups --group-ids ${SG_ID} --region ${REGION} \
            --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
        jq -c '.[]? | select(.UserIdGroupPairs | length > 0)' | while read RULE; do
            aws ec2 revoke-security-group-ingress --group-id ${SG_ID} --ip-permissions "${RULE}" --region ${REGION} 2>/dev/null || true
        done
        
        # Get and remove egress rules
        aws ec2 describe-security-groups --group-ids ${SG_ID} --region ${REGION} \
            --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
        jq -c '.[]? | select(.UserIdGroupPairs | length > 0)' | while read RULE; do
            aws ec2 revoke-security-group-egress --group-id ${SG_ID} --ip-permissions "${RULE}" --region ${REGION} 2>/dev/null || true
        done
    done
    
    # Now delete non-default security groups
    for SG_ID in ${SECURITY_GROUPS}; do
        SG_NAME=$(aws ec2 describe-security-groups --group-ids ${SG_ID} --region ${REGION} \
            --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "")
        
        if [ "${SG_NAME}" == "default" ]; then
            log_skip "Security Group" "${SG_ID} (default - will be deleted with VPC)"
            continue
        fi
        
        aws ec2 delete-security-group --group-id ${SG_ID} --region ${REGION} 2>/dev/null && \
            log_delete "Security Group" "${SG_ID}" || \
            log_error "Security Group" "${SG_ID}" "deletion failed"
    done
else
    log_skip "Security Groups" "none found"
fi

# ============================================================
# 11. Delete Subnets
# ============================================================
echo "[11/15] Deleting Subnets..."
SUBNETS=$(aws ec2 describe-subnets \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' \
    --output text 2>/dev/null || echo "")

if [ -n "${SUBNETS}" ] && [ "${SUBNETS}" != "None" ]; then
    for SUBNET_ID in ${SUBNETS}; do
        aws ec2 delete-subnet --subnet-id ${SUBNET_ID} --region ${REGION} 2>/dev/null && \
            log_delete "Subnet" "${SUBNET_ID}" || \
            log_error "Subnet" "${SUBNET_ID}" "deletion failed"
    done
else
    log_skip "Subnets" "none found"
fi

# ============================================================
# 12. Delete Route Tables
# ============================================================
echo "[12/15] Deleting Route Tables..."
ROUTE_TABLES=$(aws ec2 describe-route-tables \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[*].[RouteTableId,Associations[0].Main]' \
    --output text 2>/dev/null || echo "")

if [ -n "${ROUTE_TABLES}" ] && [ "${ROUTE_TABLES}" != "None" ]; then
    echo "${ROUTE_TABLES}" | while read RT_ID IS_MAIN; do
        [ -z "${RT_ID}" ] && continue
        
        if [ "${IS_MAIN}" == "True" ]; then
            log_skip "Route Table" "${RT_ID} (main - will be deleted with VPC)"
            continue
        fi
        
        # Remove associations first
        ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids ${RT_ID} --region ${REGION} \
            --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
            --output text 2>/dev/null || echo "")
        
        for ASSOC_ID in ${ASSOC_IDS}; do
            [ -z "${ASSOC_ID}" ] || [ "${ASSOC_ID}" == "None" ] && continue
            aws ec2 disassociate-route-table --association-id ${ASSOC_ID} --region ${REGION} 2>/dev/null || true
        done
        
        aws ec2 delete-route-table --route-table-id ${RT_ID} --region ${REGION} 2>/dev/null && \
            log_delete "Route Table" "${RT_ID}" || \
            log_error "Route Table" "${RT_ID}" "deletion failed"
    done
else
    log_skip "Route Tables" "none found"
fi

# ============================================================
# 13. Delete Route53 Records (if GUID available)
# ============================================================
echo "[13/15] Cleaning Route53 records..."

if [ -n "${GUID}" ]; then
    # Find hosted zone
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
        --query "HostedZones[?contains(Name, 'sandbox') || contains(Name, 'opentlc')].Id" \
        --output text 2>/dev/null | head -1 | sed 's|/hostedzone/||')
    
    if [ -n "${HOSTED_ZONE_ID}" ]; then
        echo "  Found hosted zone: ${HOSTED_ZONE_ID}"
        
        # Get records matching the GUID
        RECORDS=$(aws route53 list-resource-record-sets \
            --hosted-zone-id ${HOSTED_ZONE_ID} \
            --query "ResourceRecordSets[?contains(Name, '${GUID}')]" \
            --output json 2>/dev/null || echo "[]")
        
        RECORD_COUNT=$(echo "${RECORDS}" | jq 'length')
        
        if [ "${RECORD_COUNT}" -gt 0 ]; then
            echo "  Found ${RECORD_COUNT} DNS records to delete..."
            
            # Build change batch
            CHANGES=$(echo "${RECORDS}" | jq '[.[] | {Action: "DELETE", ResourceRecordSet: .}]')
            
            if [ "${CHANGES}" != "[]" ]; then
                CHANGE_BATCH="{\"Changes\": ${CHANGES}}"
                
                aws route53 change-resource-record-sets \
                    --hosted-zone-id ${HOSTED_ZONE_ID} \
                    --change-batch "${CHANGE_BATCH}" \
                    --region ${REGION} 2>/dev/null && \
                    log_delete "Route53 Records" "${RECORD_COUNT} records for ${GUID}" || \
                    log_error "Route53 Records" "${GUID}" "deletion failed"
            fi
        else
            log_skip "Route53 Records" "none found for ${GUID}"
        fi
    else
        log_skip "Route53" "no hosted zone found"
    fi
else
    log_skip "Route53 Records" "no GUID detected"
fi

# ============================================================
# 14. Delete CloudFormation Stack (if detected)
# ============================================================
echo "[14/15] Checking for CloudFormation stacks..."

if [ -n "${GUID}" ]; then
    # Try to find associated CF stack
    CF_STACKS=$(aws cloudformation list-stacks \
        --region ${REGION} \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE UPDATE_ROLLBACK_COMPLETE \
        --query "StackSummaries[?contains(StackName, '${GUID}')].StackName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${CF_STACKS}" ] && [ "${CF_STACKS}" != "None" ]; then
        for STACK_NAME in ${CF_STACKS}; do
            echo "  Deleting CloudFormation stack: ${STACK_NAME}..."
            aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION} 2>/dev/null && \
                log_delete "CloudFormation Stack" "${STACK_NAME}" || \
                log_error "CloudFormation Stack" "${STACK_NAME}" "deletion failed"
        done
        
        echo "  Waiting for stack deletion..."
        for STACK_NAME in ${CF_STACKS}; do
            aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${REGION} 2>/dev/null || true
        done
    else
        log_skip "CloudFormation Stacks" "none found for ${GUID}"
    fi
else
    log_skip "CloudFormation Stacks" "no GUID detected"
fi

# ============================================================
# 15. Delete the VPC
# ============================================================
echo "[15/15] Deleting VPC..."

# Final attempt to delete VPC
if aws ec2 delete-vpc --vpc-id ${VPC_ID} --region ${REGION} 2>/dev/null; then
    log_delete "VPC" "${VPC_ID}"
else
    echo -e "  ${RED}✗${NC} Failed to delete VPC ${VPC_ID}"
    echo ""
    echo "Checking for remaining dependencies..."
    
    # Check what's left
    REMAINING_ENI=$(aws ec2 describe-network-interfaces --region ${REGION} \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null || echo "")
    
    REMAINING_SG=$(aws ec2 describe-security-groups --region ${REGION} \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    
    REMAINING_SUBNET=$(aws ec2 describe-subnets --region ${REGION} \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].SubnetId' --output text 2>/dev/null || echo "")
    
    if [ -n "${REMAINING_ENI}" ] && [ "${REMAINING_ENI}" != "None" ]; then
        echo -e "  ${YELLOW}Remaining Network Interfaces:${NC} ${REMAINING_ENI}"
    fi
    if [ -n "${REMAINING_SG}" ] && [ "${REMAINING_SG}" != "None" ]; then
        echo -e "  ${YELLOW}Remaining Security Groups:${NC} ${REMAINING_SG}"
    fi
    if [ -n "${REMAINING_SUBNET}" ] && [ "${REMAINING_SUBNET}" != "None" ]; then
        echo -e "  ${YELLOW}Remaining Subnets:${NC} ${REMAINING_SUBNET}"
    fi
    
    echo ""
    echo "Try running this script again, or manually delete the remaining resources."
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     CLEANUP COMPLETE                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Deleted ${#DELETED_RESOURCES[@]} resources:"
for resource in "${DELETED_RESOURCES[@]}"; do
    echo "  - ${resource}"
done
echo ""

# Verify VPC is gone
if aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --region ${REGION} &>/dev/null; then
    echo -e "${YELLOW}Note: VPC ${VPC_ID} still exists. Some resources may need manual cleanup.${NC}"
else
    echo -e "${GREEN}✓ VPC ${VPC_ID} successfully deleted${NC}"
fi

