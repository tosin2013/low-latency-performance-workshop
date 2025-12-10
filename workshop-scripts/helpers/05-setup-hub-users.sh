#!/bin/bash
# Setup hub cluster for multi-user workshop
# Creates htpasswd users, installs Dev Spaces, and prepares per-user resources
#
# Usage:
#   ./05-setup-hub-users.sh [num_users] [user_prefix]
#
# Examples:
#   ./05-setup-hub-users.sh           # Setup 5 users (user1-user5)
#   ./05-setup-hub-users.sh 10        # Setup 10 users (user1-user10)
#   ./05-setup-hub-users.sh 5 student # Setup 5 users (student1-student5)
#
# Idempotent - safe to re-run

set -e

NUM_USERS=${1:-5}
USER_PREFIX=${2:-user}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
AGNOSTICD_DIR=~/agnosticd
CONFIG_NAME="low-latency-workshop-hub"

# Get workshop password from environment (set by provision-workshop.sh) or use default
HUB_USER_PASSWORD="${WORKSHOP_PASSWORD:-workshop}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     HUB CLUSTER MULTI-USER SETUP                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Users to create: ${NUM_USERS}"
echo "  Username pattern: ${USER_PREFIX}1 - ${USER_PREFIX}${NUM_USERS}"
echo "  Password: ********** (from WORKSHOP_PASSWORD)"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/5] Checking prerequisites..."

# Check oc CLI
if ! command -v oc &> /dev/null; then
    echo "✗ oc CLI not found"
    exit 1
fi
echo "✓ oc CLI available"

# Check cluster access
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into OpenShift cluster"
    echo "Run: oc login <cluster-api-url>"
    exit 1
fi
CLUSTER_API=$(oc whoami --show-server)
CLUSTER_USER=$(oc whoami)
echo "✓ Logged into cluster: ${CLUSTER_API}"
echo "  User: ${CLUSTER_USER}"

# Check cluster-admin access
if ! oc auth can-i create oauth 2>/dev/null | grep -q "yes"; then
    echo "✗ Insufficient permissions (need cluster-admin)"
    exit 1
fi
echo "✓ Cluster-admin access confirmed"

# Get cluster ingress domain
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")
echo "✓ Cluster domain: ${CLUSTER_DOMAIN}"

# Get subdomain suffix for SNO clusters
SUBDOMAIN_SUFFIX=$(echo ${CLUSTER_API} | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
export SUBDOMAIN_BASE_SUFFIX="${SUBDOMAIN_SUFFIX}"
echo "✓ Subdomain suffix: ${SUBDOMAIN_SUFFIX}"

# ============================================
# Check for AgnosticD or run directly
# ============================================
echo ""
echo "[2/5] Checking deployment method..."

USE_AGNOSTICD=false
if [ -d "${AGNOSTICD_DIR}" ] && command -v ansible-navigator &> /dev/null; then
    echo "✓ AgnosticD and ansible-navigator available"
    echo "  Using AgnosticD workloads for setup"
    USE_AGNOSTICD=true
else
    echo "⚠ AgnosticD not available, using direct oc commands"
fi

# ============================================
# Check Existing OAuth/htpasswd Configuration
# ============================================
echo ""
echo "[3/5] Checking existing OAuth configuration..."

SKIP_HTPASSWD=false
EXISTING_IDP=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[*].name}' 2>/dev/null || echo "")
EXISTING_HTPASSWD_SECRET=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.type=="HTPasswd")].htpasswd.fileData.name}' 2>/dev/null || echo "")

if [ -n "${EXISTING_IDP}" ]; then
    echo "⚠ Existing identity provider(s) found: ${EXISTING_IDP}"

    if [ -n "${EXISTING_HTPASSWD_SECRET}" ]; then
        echo "  Existing htpasswd secret: ${EXISTING_HTPASSWD_SECRET}"

        # Get existing users
        EXISTING_USERS=$(oc get secret ${EXISTING_HTPASSWD_SECRET} -n openshift-config -o jsonpath='{.data.htpasswd}' 2>/dev/null | base64 -d | cut -d: -f1 | tr '\n' ' ')
        echo "  Existing users: ${EXISTING_USERS}"

        # Check if requested users already exist
        USERS_EXIST=true
        MISSING_USERS=""
        for i in $(seq 1 ${NUM_USERS}); do
            if ! echo "${EXISTING_USERS}" | grep -qw "${USER_PREFIX}${i}"; then
                USERS_EXIST=false
                MISSING_USERS="${MISSING_USERS} ${USER_PREFIX}${i}"
            fi
        done

        if [ "${USERS_EXIST}" == "true" ]; then
            echo "✓ All ${NUM_USERS} workshop users already exist in htpasswd"
            echo ""
            echo "Options:"
            echo "  [S]kip - Keep existing OAuth/users (recommended)"
            echo "  [O]verwrite - Replace with new htpasswd (will change passwords!)"
            echo "  [A]bort - Exit script"
            echo ""
            read -p "Choice [S/o/a]: " -n 1 -r OAUTH_CHOICE
            echo ""

            case ${OAUTH_CHOICE} in
                [Oo])
                    echo "Will overwrite existing htpasswd configuration"
                    ;;
                [Aa])
                    echo "Aborting"
                    exit 0
                    ;;
                *)
                    echo "Skipping htpasswd setup - keeping existing configuration"
                    SKIP_HTPASSWD=true
                    ;;
            esac
        else
            echo "⚠ Missing users:${MISSING_USERS}"
            echo ""
            echo "Options:"
            echo "  [M]erge - Add missing users to existing htpasswd"
            echo "  [O]verwrite - Replace with new htpasswd (will reset ALL passwords!)"
            echo "  [S]kip - Keep existing OAuth as-is"
            echo "  [A]bort - Exit script"
            echo ""
            read -p "Choice [M/o/s/a]: " -n 1 -r OAUTH_CHOICE
            echo ""

            case ${OAUTH_CHOICE} in
                [Oo])
                    echo "Will overwrite existing htpasswd configuration"
                    ;;
                [Ss])
                    echo "Skipping htpasswd setup"
                    SKIP_HTPASSWD=true
                    ;;
                [Aa])
                    echo "Aborting"
                    exit 0
                    ;;
                *)
                    echo "Will merge missing users with existing htpasswd"
                    MERGE_HTPASSWD=true
                    ;;
            esac
        fi
    else
        echo "  No htpasswd provider configured - will create new one"
    fi
else
    echo "✓ No existing identity providers - will create htpasswd"
fi

# ============================================
# Create/Update htpasswd users
# ============================================
if [ "${SKIP_HTPASSWD}" != "true" ]; then
    echo ""
    echo "Creating htpasswd users..."

    HTPASSWD_SECRET="htpasswd-workshop-secret"
    HTPASSWD_FILE=$(mktemp)

    # If merging, start with existing htpasswd content
    if [ "${MERGE_HTPASSWD}" == "true" ] && [ -n "${EXISTING_HTPASSWD_SECRET}" ]; then
        echo "  Extracting existing htpasswd entries..."
        oc get secret ${EXISTING_HTPASSWD_SECRET} -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d > ${HTPASSWD_FILE}
        echo "  Existing entries preserved"
    fi

    # Check if htpasswd command exists
    if ! command -v htpasswd &> /dev/null; then
        echo "  htpasswd not found, using openssl for password hashing"
        # Generate htpasswd entries using openssl
        for i in $(seq 1 ${NUM_USERS}); do
            # Skip if user already exists (merge mode)
            if [ "${MERGE_HTPASSWD}" == "true" ] && grep -q "^${USER_PREFIX}${i}:" ${HTPASSWD_FILE} 2>/dev/null; then
                echo "  Skipping ${USER_PREFIX}${i} (already exists)"
                continue
            fi
            PASSWORD_HASH=$(openssl passwd -apr1 "${HUB_USER_PASSWORD}")
            echo "${USER_PREFIX}${i}:${PASSWORD_HASH}" >> ${HTPASSWD_FILE}
        done
        # Add admin user only if not merging or doesn't exist
        if [ "${MERGE_HTPASSWD}" != "true" ] || ! grep -q "^admin:" ${HTPASSWD_FILE} 2>/dev/null; then
            ADMIN_HASH=$(openssl passwd -apr1 "redhat123")
            echo "admin:${ADMIN_HASH}" >> ${HTPASSWD_FILE}
        fi
    else
        # Generate htpasswd entries
        for i in $(seq 1 ${NUM_USERS}); do
            # Skip if user already exists (merge mode)
            if [ "${MERGE_HTPASSWD}" == "true" ] && grep -q "^${USER_PREFIX}${i}:" ${HTPASSWD_FILE} 2>/dev/null; then
                echo "  Skipping ${USER_PREFIX}${i} (already exists)"
                continue
            fi
            htpasswd -Bbn "${USER_PREFIX}${i}" "${HUB_USER_PASSWORD}" >> ${HTPASSWD_FILE}
        done
        # Add admin user only if not merging or doesn't exist
        if [ "${MERGE_HTPASSWD}" != "true" ] || ! grep -q "^admin:" ${HTPASSWD_FILE} 2>/dev/null; then
            htpasswd -Bbn "admin" "redhat123" >> ${HTPASSWD_FILE}
        fi
    fi

    echo "  Generated credentials for ${NUM_USERS} users"

    # Create/update htpasswd secret (idempotent)
    oc create secret generic ${HTPASSWD_SECRET} \
        --from-file=htpasswd=${HTPASSWD_FILE} \
        -n openshift-config \
        --dry-run=client -o yaml | oc apply -f -

    echo "✓ htpasswd secret created/updated"

    # Update OAuth configuration (idempotent)
    echo "  Updating OAuth configuration..."

    # Create OAuth patch
    cat > /tmp/oauth-patch.yaml << EOF
spec:
  identityProviders:
  - name: workshop-htpasswd
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: ${HTPASSWD_SECRET}
EOF

    # Apply OAuth patch
    oc patch oauth cluster --type=merge --patch-file=/tmp/oauth-patch.yaml

    echo "✓ OAuth configured with htpasswd provider"

    # Wait for OAuth pods to restart
    echo "  Waiting for OAuth pods to restart..."
    sleep 10
    oc rollout status deployment/oauth-openshift -n openshift-authentication --timeout=120s 2>/dev/null || true

    # Clean up temp file
    rm -f ${HTPASSWD_FILE} /tmp/oauth-patch.yaml
else
    echo "✓ Using existing OAuth configuration"
fi

# ============================================
# Install Dev Spaces
# ============================================
echo ""
echo "[4/5] Installing Dev Spaces..."

DEVSPACES_NS="openshift-devspaces"

# Create namespace
oc create namespace ${DEVSPACES_NS} --dry-run=client -o yaml | oc apply -f -

# Check if Dev Spaces operator is already installed
if oc get csv -n ${DEVSPACES_NS} 2>/dev/null | grep -q devspaces; then
    echo "✓ Dev Spaces operator already installed"
else
    echo "  Installing Dev Spaces operator..."
    
    # Create OperatorGroup
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: devspaces-operator
  namespace: ${DEVSPACES_NS}
spec:
  targetNamespaces:
  - ${DEVSPACES_NS}
EOF

    # Create Subscription
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: devspaces
  namespace: ${DEVSPACES_NS}
spec:
  channel: stable
  installPlanApproval: Automatic
  name: devspaces
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    echo "  Waiting for Dev Spaces operator to install..."
    # Wait for CSV to be ready
    for i in {1..60}; do
        CSV_STATUS=$(oc get csv -n ${DEVSPACES_NS} -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
        if [ "${CSV_STATUS}" == "Succeeded" ]; then
            echo "✓ Dev Spaces operator installed"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "⚠ Operator installation taking longer than expected"
            echo "  Check: oc get csv -n ${DEVSPACES_NS}"
        fi
        sleep 10
    done
fi

# Wait for CheCluster CRD
echo "  Waiting for CheCluster CRD..."
for i in {1..30}; do
    if oc get crd checlusters.org.eclipse.che &>/dev/null; then
        break
    fi
    sleep 5
done

# Create CheCluster instance (idempotent)
echo "  Creating CheCluster instance..."
cat << EOF | oc apply -f -
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: ${DEVSPACES_NS}
  labels:
    workshop: low-latency
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    dashboard:
      headerMessage:
        show: true
        text: "Low-Latency Performance Workshop - Dev Spaces"
  devEnvironments:
    startTimeoutSeconds: 600
    maxNumberOfRunningWorkspacesPerUser: 1
    maxNumberOfWorkspacesPerUser: -1
    secondsOfInactivityBeforeIdling: 1800
    storage:
      pvcStrategy: per-user
    defaultNamespace:
      autoProvision: true
      template: "<username>-devspaces"
    defaultEditor: che-code
EOF

echo "✓ CheCluster instance created/updated"

# ============================================
# Create user namespaces and resources
# ============================================
echo ""
echo "[5/5] Creating user namespaces and resources..."

for i in $(seq 1 ${NUM_USERS}); do
    USER_NAME="${USER_PREFIX}${i}"
    USER_NS="workshop-${USER_NAME}"
    
    echo "  Setting up ${USER_NAME}..."
    
    # Create namespace (idempotent)
    oc create namespace ${USER_NS} --dry-run=client -o yaml | oc apply -f -
    
    # Label namespace
    oc label namespace ${USER_NS} \
        workshop=low-latency \
        user=${USER_NAME} \
        --overwrite
    
    # Create RoleBinding (idempotent)
    cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USER_NAME}-admin
  namespace: ${USER_NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: ${USER_NAME}
EOF
    
    # Create placeholder secrets for Dev Spaces (will be updated later)
    # Kubeconfig secret
    cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${USER_NAME}-kubeconfig
  namespace: ${USER_NS}
  labels:
    workshop: low-latency
    user: ${USER_NAME}
    controller.devfile.io/mount-to-devworkspace: "true"
    controller.devfile.io/watch-secret: "true"
  annotations:
    controller.devfile.io/mount-path: /home/user/.kube
    controller.devfile.io/mount-as: subpath
stringData:
  config: |
    # Placeholder - will be updated when SNO is deployed
    apiVersion: v1
    kind: Config
    clusters: []
    contexts: []
    current-context: ""
    users: []
type: Opaque
EOF

    # SSH key secret
    cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${USER_NAME}-ssh-key
  namespace: ${USER_NS}
  labels:
    workshop: low-latency
    user: ${USER_NAME}
    controller.devfile.io/mount-to-devworkspace: "true"
    controller.devfile.io/watch-secret: "true"
  annotations:
    controller.devfile.io/mount-path: /home/user/.ssh
    controller.devfile.io/mount-as: subpath
stringData:
  id_rsa: |
    # Placeholder - will be updated when SNO is deployed
type: Opaque
EOF

    # Create SNO info ConfigMap
    SNO_GUID="workshop-${USER_NAME}"
    cat << EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${USER_NAME}-sno-info
  namespace: ${USER_NS}
  labels:
    workshop: low-latency
    user: ${USER_NAME}
data:
  SNO_GUID: "${SNO_GUID}"
  SNO_API_URL: "https://api.${SNO_GUID}${SUBDOMAIN_SUFFIX}:6443"
  SNO_CONSOLE_URL: "https://console-openshift-console.apps.${SNO_GUID}${SUBDOMAIN_SUFFIX}"
  USER_NAME: "${USER_NAME}"
  KUBECONFIG_READY: "false"
  SSH_KEY_READY: "false"
EOF

done

echo "✓ All user namespaces created"

# ============================================
# Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     HUB CLUSTER SETUP COMPLETE                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Users Created: ${NUM_USERS}"
echo ""
echo "User Credentials:"
for i in $(seq 1 ${NUM_USERS}); do
    echo "  ${USER_PREFIX}${i} / <workshop-password>"
done
echo "  admin / redhat123"
echo ""
echo "Dev Spaces URL: https://devspaces.${CLUSTER_DOMAIN}"
echo ""
echo "Namespaces Created:"
for i in $(seq 1 ${NUM_USERS}); do
    echo "  workshop-${USER_PREFIX}${i}"
done
echo ""
echo "Next Steps:"
echo "  1. Deploy SNO clusters: ./06-provision-user-snos.sh ${NUM_USERS}"
echo "  2. Update Dev Spaces secrets: ./07-setup-user-devspaces.sh ${NUM_USERS}"
echo "  3. Setup module-02: ./09-setup-module02-rhacm.sh"
echo ""
echo "Users can now:"
echo "  1. Login to OpenShift console with ${USER_PREFIX}N / <workshop-password>"
echo "  2. Access Dev Spaces at https://devspaces.${CLUSTER_DOMAIN}"
echo "  3. Start the 'low-latency-workshop' workspace"
echo ""

