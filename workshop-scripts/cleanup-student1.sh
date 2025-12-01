#!/bin/bash
set -e

VPC_ID=""
REGION="us-east-2"

echo "=== Step 1: Deleting Load Balancers ==="

# Delete ELBv2 (Application/Network Load Balancers)
echo "Deleting Network Load Balancers..."
for lb_arn in $(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text); do
  echo "  Deleting: $lb_arn"
  aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn "$lb_arn"
done

# Delete Classic Load Balancers
echo "Deleting Classic Load Balancers..."
for lb_name in $(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text); do
  echo "  Deleting: $lb_name"
  aws elb delete-load-balancer --region $REGION --load-balancer-name "$lb_name"
done

echo "Waiting for load balancers to be deleted (30 seconds)..."
sleep 30

echo -e "\n=== Step 2: Deleting NAT Gateways ==="
for nat_id in $(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text); do
  echo "  Deleting NAT Gateway: $nat_id"
  aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id "$nat_id"
done

if [ -n "$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,deleting" --query 'NatGateways[*].NatGatewayId' --output text)" ]; then
  echo "Waiting for NAT Gateways to be deleted (60 seconds)..."
  sleep 60
fi

echo -e "\n=== Step 3: Deleting VPC Endpoints ==="
for vpce_id in $(aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[*].VpcEndpointId' --output text); do
  echo "  Deleting VPC Endpoint: $vpce_id"
  aws ec2 delete-vpc-endpoints --region $REGION --vpc-endpoint-ids "$vpce_id"
done

echo -e "\n=== Step 4: Detaching and Deleting Internet Gateways ==="
for igw_id in $(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[*].InternetGatewayId' --output text); do
  echo "  Detaching IGW: $igw_id"
  aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id "$igw_id" --vpc-id "$VPC_ID"
  echo "  Deleting IGW: $igw_id"
  aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id "$igw_id"
done

echo -e "\n=== Step 5: Deleting Network Interfaces ==="
for eni_id in $(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text); do
  echo "  Deleting ENI: $eni_id"
  aws ec2 delete-network-interface --region $REGION --network-interface-id "$eni_id"
done

echo -e "\n=== Step 6: Deleting Subnets ==="
for subnet_id in $(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text); do
  echo "  Deleting Subnet: $subnet_id"
  aws ec2 delete-subnet --region $REGION --subnet-id "$subnet_id" || true
done

echo -e "\n=== Step 7: Deleting Security Groups ==="
for sg_id in $(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
  echo "  Deleting Security Group: $sg_id"
  aws ec2 delete-security-group --region $REGION --group-id "$sg_id" || true
done

echo -e "\n=== Step 8: Deleting Route Tables ==="
for rt_id in $(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
  echo "  Deleting Route Table: $rt_id"
  aws ec2 delete-route-table --region $REGION --route-table-id "$rt_id" || true
done

echo -e "\n=== Step 9: Deleting VPC ==="
echo "Attempting to delete VPC: $VPC_ID"
aws ec2 delete-vpc --region $REGION --vpc-id "$VPC_ID" && echo "✅ VPC deleted successfully!" || echo "❌ VPC deletion failed - may need manual cleanup"

echo -e "\n✅ Cleanup script completed!"
