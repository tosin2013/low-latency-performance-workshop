#!/bin/bash
#
# Script to delete Route53 hosted zones for hub and student clusters
# Usage: ./cleanup-route53-zones.sh [sandbox-name]
#   If sandbox-name is provided, only zones matching that sandbox will be deleted
#   If not provided, will prompt for confirmation before deleting all matching zones
#

set -euo pipefail

SANDBOX_NAME="${1:-}"
DRY_RUN="${DRY_RUN:-false}"

# Function to delete a hosted zone
delete_hosted_zone() {
    local zone_id=$1
    local zone_name=$2
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would delete: $zone_name ($zone_id)"
        return 0
    fi
    
    echo "  Deleting hosted zone: $zone_name ($zone_id)"
    
    # First, delete all records in the zone (except NS and SOA)
    local records=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`].{Name:Name,Type:Type}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$records" ] && [ "$records" != "None" ]; then
        echo "    Deleting records in zone..."
        while IFS=$'\t' read -r name type; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                # Get the full record set to delete it
                local change_batch=$(aws route53 list-resource-record-sets \
                    --hosted-zone-id "$zone_id" \
                    --query "ResourceRecordSets[?Name=='$name' && Type=='$type']" \
                    --output json 2>/dev/null | jq -r '.[0] | {Action: "DELETE", ResourceRecordSet: .}' | jq -s '{Changes: .}')
                
                if [ -n "$change_batch" ] && [ "$change_batch" != "null" ]; then
                    aws route53 change-resource-record-sets \
                        --hosted-zone-id "$zone_id" \
                        --change-batch "$change_batch" >/dev/null 2>&1 || true
                fi
            fi
        done <<< "$records"
    fi
    
    # Delete the hosted zone
    if aws route53 delete-hosted-zone --id "$zone_id" >/dev/null 2>&1; then
        echo "    ✅ Hosted zone deleted"
    else
        echo "    ⚠️  Failed to delete hosted zone (may have dependencies)"
    fi
}

# Get all hosted zones
echo "=== Route53 Hosted Zone Cleanup ==="
echo ""

if [ -n "$SANDBOX_NAME" ]; then
    echo "Filtering for sandbox: $SANDBOX_NAME"
    FILTER="Name=Name,Values=*${SANDBOX_NAME}*"
else
    echo "Finding all hub and student hosted zones..."
    FILTER=""
fi

# Get public hosted zones
echo ""
echo "Public Hosted Zones:"
PUBLIC_ZONES=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Config.PrivateZone==\`false\` && (contains(Name, \`student\`) || contains(Name, \`hub\`) || contains(Name, \`sandbox\`))].{Id:Id,Name:Name}" \
    --output json 2>/dev/null)

if [ -n "$SANDBOX_NAME" ]; then
    PUBLIC_ZONES=$(echo "$PUBLIC_ZONES" | jq -r --arg sandbox "$SANDBOX_NAME" '[.[] | select(.Name | contains($sandbox))]')
fi

# Exclude the base sandbox domain (e.g., sandbox3576.opentlc.com) - only delete subdomains
if [ -n "$SANDBOX_NAME" ]; then
    BASE_DOMAIN="${SANDBOX_NAME}.opentlc.com."
    PUBLIC_ZONES=$(echo "$PUBLIC_ZONES" | jq -r --arg base "$BASE_DOMAIN" '[.[] | select(.Name != $base)]')
    echo "  Excluding base domain: $BASE_DOMAIN"
fi

PUBLIC_COUNT=$(echo "$PUBLIC_ZONES" | jq -r 'length')
echo "  Found $PUBLIC_COUNT public hosted zone(s)"

if [ "$PUBLIC_COUNT" -gt 0 ]; then
    echo "$PUBLIC_ZONES" | jq -r '.[] | "    - \(.Name) (\(.Id))"'
fi

# Get private hosted zones (ocp.*)
echo ""
echo "Private Hosted Zones (ocp.*):"
PRIVATE_ZONES=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Config.PrivateZone==\`true\` && contains(Name, \`ocp\`)].{Id:Id,Name:Name}" \
    --output json 2>/dev/null)

if [ -n "$SANDBOX_NAME" ]; then
    PRIVATE_ZONES=$(echo "$PRIVATE_ZONES" | jq -r --arg sandbox "$SANDBOX_NAME" '[.[] | select(.Name | contains($sandbox))]')
fi

PRIVATE_COUNT=$(echo "$PRIVATE_ZONES" | jq -r 'length')
echo "  Found $PRIVATE_COUNT private hosted zone(s)"

if [ "$PRIVATE_COUNT" -gt 0 ]; then
    echo "$PRIVATE_ZONES" | jq -r '.[] | "    - \(.Name) (\(.Id))"'
fi

TOTAL_COUNT=$((PUBLIC_COUNT + PRIVATE_COUNT))

if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo ""
    echo "✅ No hosted zones found to delete."
    exit 0
fi

echo ""
echo "Total: $TOTAL_COUNT hosted zone(s) to delete"

if [ "$DRY_RUN" = "true" ]; then
    echo ""
    echo "=== DRY RUN MODE - No zones will be deleted ==="
    echo ""
fi

# Confirm deletion
if [ "$DRY_RUN" != "true" ]; then
    echo ""
    read -p "Delete these hosted zones? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Delete public zones
if [ "$PUBLIC_COUNT" -gt 0 ]; then
    echo ""
    echo "Deleting public hosted zones..."
    echo "$PUBLIC_ZONES" | jq -r '.[] | "\(.Id)|\(.Name)"' | while IFS='|' read -r zone_id zone_name; do
        delete_hosted_zone "$zone_id" "$zone_name"
    done
fi

# Delete private zones
if [ "$PRIVATE_COUNT" -gt 0 ]; then
    echo ""
    echo "Deleting private hosted zones..."
    echo "$PRIVATE_ZONES" | jq -r '.[] | "\(.Id)|\(.Name)"' | while IFS='|' read -r zone_id zone_name; do
        delete_hosted_zone "$zone_id" "$zone_name"
    done
fi

echo ""
echo "✅ Hosted zone cleanup completed!"
