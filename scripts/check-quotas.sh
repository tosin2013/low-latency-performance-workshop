#!/usr/bin/env bash
# check-quotas.sh — Verify and optionally request AWS quota increases
#
# This script checks that your AWS account has sufficient quotas for
# deploying the Low-Latency Performance Workshop SNO clusters.
#
# Usage:
#   ./scripts/check-quotas.sh                      # Check quotas (default region)
#   ./scripts/check-quotas.sh --region us-west-2   # Check quotas in specific region
#   ./scripts/check-quotas.sh --students 3         # Check for 3 students (default: 2)
#   ./scripts/check-quotas.sh --request            # Request increases for failed quotas

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

pass()  { echo -e "  ${GREEN}[PASS]${RESET} $*"; }
fail()  { echo -e "  ${RED}[FAIL]${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
info()  { echo -e "${BLUE}[INFO]${RESET} $*"; }

# ─── Defaults ────────────────────────────────────────────────────────────────

REGION="${AWS_DEFAULT_REGION:-us-east-2}"
NUM_STUDENTS=2
REQUEST_INCREASE=false

# Load from workshop-config.yml if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../workshop-config.yml"

if [[ -f "$CONFIG_FILE" ]]; then
    cfg_region=$(grep '^aws_region:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    cfg_students=$(grep '^num_students:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    [[ -n "$cfg_region" ]] && REGION="$cfg_region"
    [[ -n "$cfg_students" ]] && NUM_STUDENTS="$cfg_students"
fi

# ─── Argument Parsing ────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --region)   REGION="${2:-$REGION}"; shift 2 ;;
        --students) NUM_STUDENTS="${2:-$NUM_STUDENTS}"; shift 2 ;;
        --request)  REQUEST_INCREASE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--region REGION] [--students N] [--request]"
            echo ""
            echo "Options:"
            echo "  --region REGION   AWS region to check (default: us-east-2)"
            echo "  --students N      Number of student clusters (default: 2)"
            echo "  --request         Request quota increases for any failures"
            echo ""
            echo "Reads defaults from workshop-config.yml if available."
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Verify AWS CLI ──────────────────────────────────────────────────────────

if ! command -v aws &>/dev/null; then
    echo "ERROR: AWS CLI is not installed. Run 'make setup' first."
    exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS credentials not configured."
    echo "  Get credentials from demo.redhat.com (AWS Open Environment)"
    echo "  Then run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
info "AWS Account: ${ACCOUNT_ID}"
info "Region: ${REGION}"
info "Students: ${NUM_STUDENTS}"
echo ""

# ─── Quota Definitions ───────────────────────────────────────────────────────
# Per-student resource needs:
#   - SNO node: 16 vCPUs (m5.4xlarge)
#   - Bastion: 2 vCPUs (t3a.medium)
#   - Total: 18 vCPUs per student + buffer = 20
#   - EIPs: 2 per student (bastion + cluster) + 1 buffer = 3
#   - VPCs: 1 per student + 1 for hub = students + 1

VCPUS_NEEDED=$(( NUM_STUDENTS * 20 ))
EIPS_NEEDED=$(( NUM_STUDENTS * 3 ))
VPCS_NEEDED=$(( NUM_STUDENTS + 1 ))

# Quota codes
VCPU_QUOTA_CODE="L-1216C47A"    # Running On-Demand Standard instances
EIP_QUOTA_CODE="L-0263D0A3"     # EC2-VPC Elastic IPs
VPC_QUOTA_CODE="L-F678F1CE"     # VPCs per Region

# ─── Check Functions ─────────────────────────────────────────────────────────

check_quota() {
    local label="$1" service_code="$2" quota_code="$3" needed="$4"

    local limit
    limit=$(aws service-quotas get-service-quota \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --region "$REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")

    # Truncate to integer
    limit="${limit%%.*}"
    limit="${limit:-0}"

    if (( limit >= needed )); then
        pass "${label}: quota ${limit}, need ${needed}"
        return 0
    else
        fail "${label}: quota ${limit}, need ${needed} (short by $((needed - limit)))"
        return 1
    fi
}

request_quota_increase() {
    local service_code="$1" quota_code="$2" desired="$3" label="$4"

    info "Requesting increase for ${label} to ${desired} in ${REGION}..."
    local request_id
    request_id=$(aws service-quotas request-service-quota-increase \
        --service-code "$service_code" \
        --quota-code "$quota_code" \
        --desired-value "$desired" \
        --region "$REGION" \
        --query 'RequestedQuota.Id' \
        --output text 2>&1)

    if [[ $? -eq 0 ]]; then
        pass "Request submitted: ${request_id}"
        echo "      Check status: aws service-quotas get-requested-service-quota-change --request-id ${request_id} --region ${REGION}"
    else
        fail "Request failed: ${request_id}"
        echo "      Manual request: https://${REGION}.console.aws.amazon.com/servicequotas/home/services/${service_code}/quotas/${quota_code}"
    fi
}

# ─── Run Checks ──────────────────────────────────────────────────────────────

echo -e "${BOLD}--- AWS Quota Check (${REGION}) ---${RESET}"
echo ""
echo "  Resources needed for ${NUM_STUDENTS} student(s):"
echo "    vCPUs: ${VCPUS_NEEDED}  |  Elastic IPs: ${EIPS_NEEDED}  |  VPCs: ${VPCS_NEEDED}"
echo ""

FAILURES=0

if ! check_quota "EC2 vCPUs (On-Demand Standard)" "ec2" "$VCPU_QUOTA_CODE" "$VCPUS_NEEDED"; then
    FAILURES=$((FAILURES + 1))
    if [[ "$REQUEST_INCREASE" == "true" ]]; then
        request_quota_increase "ec2" "$VCPU_QUOTA_CODE" "$VCPUS_NEEDED" "EC2 vCPUs"
    fi
fi

if ! check_quota "Elastic IPs" "ec2" "$EIP_QUOTA_CODE" "$EIPS_NEEDED"; then
    FAILURES=$((FAILURES + 1))
    if [[ "$REQUEST_INCREASE" == "true" ]]; then
        request_quota_increase "ec2" "$EIP_QUOTA_CODE" "$EIPS_NEEDED" "Elastic IPs"
    fi
fi

if ! check_quota "VPCs per Region" "vpc" "$VPC_QUOTA_CODE" "$VPCS_NEEDED"; then
    FAILURES=$((FAILURES + 1))
    if [[ "$REQUEST_INCREASE" == "true" ]]; then
        request_quota_increase "vpc" "$VPC_QUOTA_CODE" "$VPCS_NEEDED" "VPCs"
    fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
if (( FAILURES == 0 )); then
    echo -e "${GREEN}${BOLD}All quota checks passed.${RESET} You have sufficient capacity to deploy."
    exit 0
else
    echo -e "${RED}${BOLD}${FAILURES} quota check(s) failed.${RESET}"
    echo ""
    if [[ "$REQUEST_INCREASE" != "true" ]]; then
        echo "  To request increases automatically, re-run with:"
        echo "    ./scripts/check-quotas.sh --request"
        echo ""
        echo "  Or request manually at:"
        echo "    https://${REGION}.console.aws.amazon.com/servicequotas/"
    else
        echo "  Quota increase requests submitted. Typical approval time: 5-15 minutes."
        echo "  Check status with:"
        echo "    aws service-quotas list-requested-service-quota-change-history --region ${REGION} --query 'RequestedQuotas[?Status==\`PENDING\`]'"
    fi
    exit 1
fi
