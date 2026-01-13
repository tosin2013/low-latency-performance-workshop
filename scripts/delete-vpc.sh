#!/bin/bash
#
# Idempotent script to delete a VPC and all its dependencies
# Usage: ./delete-vpc.sh <vpc-id>
#

set -euo pipefail

VPC_ID="${1:-}"
if [ -z "$VPC_ID" ]; then
    echo "Usage: $0 <vpc-id>"
    exit 1
fi

echo "Checking if VPC ${VPC_ID} exists..."
if ! aws ec2 describe-vpcs --vpc-ids "$VPC_ID" >/dev/null 2>&1; then
    echo "✅ VPC ${VPC_ID} does not exist or has already been deleted."
    exit 0
fi

echo "VPC ${VPC_ID} found. Starting deletion process..."

# Get VPC region from AWS config or use default
if [ -z "${AWS_DEFAULT_REGION:-}" ]; then
    AWS_DEFAULT_REGION=$(aws configure get region || echo "us-east-2")
fi
export AWS_DEFAULT_REGION

echo "Using region: ${AWS_DEFAULT_REGION}"

# Detect OpenShift clusters by checking security group naming patterns
detect_openshift() {
    local openshift_sgs=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'SecurityGroups[?contains(GroupName, `-apiserver-lb`) || contains(GroupName, `-controlplane`) || contains(GroupName, `-node`)].GroupName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$openshift_sgs" ] && [ "$openshift_sgs" != "None" ]; then
        echo "⚠️  OpenShift cluster detected in this VPC (security groups: $openshift_sgs)"
        echo "   This script will attempt to clean up OpenShift resources."
        echo "   If the cluster still exists, consider using 'openshift-install destroy cluster' first."
        echo ""
        return 0
    fi
    return 1
}

# Detect OpenShift before starting
if detect_openshift; then
    OPENSHIFT_DETECTED=true
else
    OPENSHIFT_DETECTED=false
fi

# Function to delete resources with error handling
delete_resource() {
    local aws_command=$1
    local resource_id=$2
    local description=$3
    
    if [ -z "$resource_id" ] || [ "$resource_id" == "None" ]; then
        return 0
    fi
    
    echo "  Deleting ${description} (${resource_id})..."
    if eval "$aws_command" >/dev/null 2>&1; then
        echo "    ✅ ${description} deleted"
    else
        echo "    ⚠️  ${description} may not exist or already deleted (continuing...)"
    fi
}

# 1. Delete Internet Gateways
echo "Step 1: Detaching and deleting Internet Gateways..."
IGW_IDS=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[*].InternetGatewayId' \
    --output text 2>/dev/null || echo "")

for IGW_ID in $IGW_IDS; do
    if [ -n "$IGW_ID" ]; then
        echo "  Detaching Internet Gateway ${IGW_ID}..."
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || true
        delete_resource "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID" "$IGW_ID" "Internet Gateway"
    fi
done

# 2. Delete NAT Gateways
echo "Step 2: Deleting NAT Gateways..."
NAT_IDS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NatGateways[?State==`available` || State==`pending`].NatGatewayId' \
    --output text 2>/dev/null || echo "")

for NAT_ID in $NAT_IDS; do
    if [ -n "$NAT_ID" ]; then
        echo "  Deleting NAT Gateway ${NAT_ID} (this may take a few minutes)..."
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" >/dev/null 2>&1 || true
        # Wait for NAT gateway to be deleted
        echo "    Waiting for NAT Gateway ${NAT_ID} to be deleted..."
        aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID" 2>/dev/null || true
        echo "    ✅ NAT Gateway ${NAT_ID} deleted"
    fi
done

# 3. Delete VPC Endpoints
echo "Step 3: Deleting VPC Endpoints..."
ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'VpcEndpoints[*].VpcEndpointId' \
    --output text 2>/dev/null || echo "")

for ENDPOINT_ID in $ENDPOINT_IDS; do
    if [ -n "$ENDPOINT_ID" ]; then
        delete_resource "aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $ENDPOINT_ID" "$ENDPOINT_ID" "VPC Endpoint"
    fi
done

# 4. Delete VPC Peering Connections
echo "Step 4: Deleting VPC Peering Connections..."
PEERING_IDS=$(aws ec2 describe-vpc-peering-connections \
    --filters "Name=requester-vpc-info.vpc-id,Values=${VPC_ID}" \
    --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' \
    --output text 2>/dev/null || echo "")

for PEERING_ID in $PEERING_IDS; do
    if [ -n "$PEERING_ID" ]; then
        delete_resource "aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID" "$PEERING_ID" "VPC Peering Connection"
    fi
done

# 5. Delete Route Tables (except main)
echo "Step 5: Deleting Route Tables..."
# First, disassociate all route table associations (except main)
ALL_RT_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[*].RouteTableId' \
    --output text 2>/dev/null || echo "")

for RT_ID in $ALL_RT_IDS; do
    if [ -n "$RT_ID" ]; then
        # Get all non-main associations for this route table
        ASSOCIATION_IDS=$(aws ec2 describe-route-tables \
            --route-table-ids "$RT_ID" \
            --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' \
            --output text 2>/dev/null || echo "")
        
        for ASSOC_ID in $ASSOCIATION_IDS; do
            if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
                echo "  Disassociating Route Table Association ${ASSOC_ID}..."
                aws ec2 disassociate-route-table --association-id "$ASSOC_ID" >/dev/null 2>&1 || true
            fi
        done
    fi
done

# Now delete non-main route tables
RT_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
    --output text 2>/dev/null || echo "")

for RT_ID in $RT_IDS; do
    if [ -n "$RT_ID" ]; then
        delete_resource "aws ec2 delete-route-table --route-table-id $RT_ID" "$RT_ID" "Route Table"
    fi
done

# Note: Main route table cannot be deleted directly, but will be cleaned up with VPC

# 6. Delete Load Balancers (ELBv2/ALB and Classic ELB)
echo "Step 6: Deleting Load Balancers..."

# Delete Application/Network Load Balancers (ELBv2)
ALB_ARNs=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" \
    --output text 2>/dev/null || echo "")

for ALB_ARN in $ALB_ARNs; do
    if [ -n "$ALB_ARN" ]; then
        echo "  Deleting Load Balancer ${ALB_ARN}..."
        if aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" >/dev/null 2>&1; then
            echo "    ✅ Load Balancer ${ALB_ARN} deletion initiated"
        else
            echo "    ⚠️  Failed to delete Load Balancer ${ALB_ARN}"
        fi
    fi
done

# Wait for load balancers to be deleted
if [ -n "$ALB_ARNs" ]; then
    echo "  Waiting for Load Balancers to be deleted (this may take a few minutes)..."
    for ALB_ARN in $ALB_ARNs; do
        if [ -n "$ALB_ARN" ]; then
            aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN" 2>/dev/null || true
        fi
    done
    echo "    ✅ Load Balancers deleted"
fi

# Delete Classic Load Balancers
CLB_NAMES=$(aws elb describe-load-balancers \
    --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" \
    --output text 2>/dev/null || echo "")

for CLB_NAME in $CLB_NAMES; do
    if [ -n "$CLB_NAME" ]; then
        echo "  Deleting Classic Load Balancer ${CLB_NAME}..."
        if aws elb delete-load-balancer --load-balancer-name "$CLB_NAME" >/dev/null 2>&1; then
            echo "    ✅ Classic Load Balancer ${CLB_NAME} deleted"
        else
            echo "    ⚠️  Failed to delete Classic Load Balancer ${CLB_NAME}"
        fi
    fi
done

# 7. Delete Network Interfaces
echo "Step 7: Deleting Network Interfaces..."
ENI_IDS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' \
    --output text 2>/dev/null || echo "")

for ENI_ID in $ENI_IDS; do
    if [ -n "$ENI_ID" ]; then
        # Check if ENI is attached
        ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
        if [ -n "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
            echo "  Detaching Network Interface ${ENI_ID}..."
            aws ec2 detach-network-interface --attachment-id "$ATTACHMENT_ID" --force 2>/dev/null || true
            # Wait a moment for detachment
            sleep 2
        fi
        echo "  Deleting Network Interface ${ENI_ID}..."
        if aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null; then
            echo "    ✅ Network Interface ${ENI_ID} deleted"
        else
            echo "    ⚠️  Network Interface ${ENI_ID} may still be in use (continuing...)"
        fi
    fi
done

# 8. Delete Subnets
echo "Step 8: Deleting Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' \
    --output text 2>/dev/null || echo "")

for SUBNET_ID in $SUBNET_IDS; do
    if [ -n "$SUBNET_ID" ]; then
        delete_resource "aws ec2 delete-subnet --subnet-id $SUBNET_ID" "$SUBNET_ID" "Subnet"
    fi
done

# 9. Delete Network ACLs (except default)
echo "Step 9: Deleting Network ACLs..."
NACL_IDS=$(aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NetworkAcls[?IsDefault!=`true`].NetworkAclId' \
    --output text 2>/dev/null || echo "")

for NACL_ID in $NACL_IDS; do
    if [ -n "$NACL_ID" ]; then
        delete_resource "aws ec2 delete-network-acl --network-acl-id $NACL_ID" "$NACL_ID" "Network ACL"
    fi
done

# 10. Delete Security Groups (except default)
echo "Step 10: Deleting Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text 2>/dev/null || echo "")

# Step 10a: Remove security group rules that reference other security groups
# This is critical for OpenShift clusters where security groups cross-reference each other
if [ -n "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
    echo "  Removing security group cross-references (required for OpenShift)..."
    for SG_ID in $SG_IDS; do
        if [ -n "$SG_ID" ]; then
            # Remove ingress rules that reference other security groups
            INGRESS_RULES=$(aws ec2 describe-security-groups \
                --group-ids "$SG_ID" \
                --query 'SecurityGroups[0].IpPermissions[?length(UserIdGroupPairs) > `0`]' \
                --output json 2>/dev/null || echo "[]")
            
            if [ "$INGRESS_RULES" != "[]" ] && [ -n "$INGRESS_RULES" ]; then
                echo "    Removing ingress rules from Security Group ${SG_ID}..."
                aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --ip-permissions "$INGRESS_RULES" >/dev/null 2>&1 || true
            fi
            
            # Remove egress rules that reference other security groups
            EGRESS_RULES=$(aws ec2 describe-security-groups \
                --group-ids "$SG_ID" \
                --query 'SecurityGroups[0].IpPermissionsEgress[?length(UserIdGroupPairs) > `0`]' \
                --output json 2>/dev/null || echo "[]")
            
            if [ "$EGRESS_RULES" != "[]" ] && [ -n "$EGRESS_RULES" ]; then
                echo "    Removing egress rules from Security Group ${SG_ID}..."
                aws ec2 revoke-security-group-egress --group-id "$SG_ID" --ip-permissions "$EGRESS_RULES" >/dev/null 2>&1 || true
            fi
        fi
    done
    echo "  ✅ Security group cross-references removed"
    echo ""
fi

# Step 10b: Attempt to delete security groups
for SG_ID in $SG_IDS; do
    if [ -n "$SG_ID" ]; then
        # Try to delete the security group (AWS will handle dependencies)
        # If it fails due to dependencies, we'll continue and try again
        echo "  Deleting Security Group ${SG_ID}..."
        if aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null; then
            echo "    ✅ Security Group ${SG_ID} deleted"
        else
            echo "    ⚠️  Security Group ${SG_ID} may have dependencies (will retry)"
        fi
    fi
done

# Step 10c: Retry security group deletion with multiple passes
# This is especially important for OpenShift clusters
MAX_RETRIES=3
RETRY_DELAY=5

for RETRY in $(seq 1 $MAX_RETRIES); do
    REMAINING_SGS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$REMAINING_SGS" ] || [ "$REMAINING_SGS" == "None" ]; then
        break
    fi
    
    if [ $RETRY -gt 1 ]; then
        echo "  Retry pass $RETRY of $MAX_RETRIES (waiting ${RETRY_DELAY}s for dependencies to clear)..."
        sleep $RETRY_DELAY
        RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
    fi
    
    for SG_ID in $REMAINING_SGS; do
        if [ -n "$SG_ID" ]; then
            if aws ec2 describe-security-groups --group-ids "$SG_ID" >/dev/null 2>&1; then
                echo "  Retrying deletion of Security Group ${SG_ID}..."
                if aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null; then
                    echo "    ✅ Security Group ${SG_ID} deleted"
                else
                    echo "    ⚠️  Security Group ${SG_ID} still has dependencies"
                fi
            fi
        fi
    done
done

# 11. Delete VPC
echo "Step 11: Deleting VPC..."
if aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null; then
    echo "✅ VPC ${VPC_ID} deleted successfully!"
else
    echo "❌ Failed to delete VPC ${VPC_ID}. It may still have dependencies."
    echo ""
    
    if [ "$OPENSHIFT_DETECTED" = true ]; then
        echo "⚠️  OpenShift-specific cleanup suggestions:"
        echo "   1. If the OpenShift cluster still exists, use 'openshift-install destroy cluster' first"
        echo "   2. Check for remaining security groups:"
        echo "      aws ec2 describe-security-groups --filters Name=vpc-id,Values=${VPC_ID}"
        echo "   3. Check for remaining route tables:"
        echo "      aws ec2 describe-route-tables --filters Name=vpc-id,Values=${VPC_ID}"
        echo "   4. Check for remaining network interfaces:"
        echo "      aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=${VPC_ID}"
    else
        echo "   Check for any remaining resources:"
        echo "   aws ec2 describe-vpcs --vpc-ids ${VPC_ID}"
        echo ""
        echo "   Common remaining resources:"
        echo "   - Security Groups: aws ec2 describe-security-groups --filters Name=vpc-id,Values=${VPC_ID}"
        echo "   - Route Tables: aws ec2 describe-route-tables --filters Name=vpc-id,Values=${VPC_ID}"
        echo "   - Network Interfaces: aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=${VPC_ID}"
    fi
    
    exit 1
fi

echo ""
echo "✅ VPC deletion completed successfully!"

