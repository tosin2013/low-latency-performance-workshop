#!/bin/bash
# ===================================================================
# Deploy Per-Student Showroom Instances
# ===================================================================
# This script deploys additional Showroom instances on the Hub cluster,
# one for each student, using the same Showroom template as AgnosticD.
#
# Usage:
#   ./deploy-student-showrooms.sh [--students student1,student2,...]
#
# Prerequisites:
#   - Hub cluster deployed and accessible
#   - Student credentials available in ~/Development/agnosticd-v2-output/
#   - oc CLI installed
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
NAMESPACE="low-latency-workshop"
CONTENT_REPO="https://github.com/tosin2013/low-latency-performance-workshop.git"
CONTENT_REF="main"
OUTPUT_DIR="${HOME}/Development/agnosticd-v2-output"
HUB_KUBECONFIG="${OUTPUT_DIR}/hub-cluster/openshift-cluster_hub-cluster_kubeconfig"

# Parse arguments
STUDENTS="student1,student2"
while [[ $# -gt 0 ]]; do
    case $1 in
        --students)
            STUDENTS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v oc &> /dev/null; then
    echo -e "${RED}Error: oc CLI not found. Please install it first.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ oc CLI found${NC}"

if [ ! -f "$HUB_KUBECONFIG" ]; then
    echo -e "${RED}Error: Hub kubeconfig not found at $HUB_KUBECONFIG${NC}"
    echo "Make sure the Hub cluster is deployed first."
    exit 1
fi
echo -e "${GREEN}  ✓ Hub kubeconfig found${NC}"

export KUBECONFIG="$HUB_KUBECONFIG"

if ! oc whoami &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Hub cluster${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Connected to Hub cluster as $(oc whoami)${NC}"

# Get the cluster ingress domain
INGRESS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
echo -e "${GREEN}  ✓ Ingress domain: ${INGRESS_DOMAIN}${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Per-Student Showroom Instances${NC}"
echo -e "${GREEN}========================================${NC}"

# Parse students list
IFS=',' read -ra STUDENT_ARRAY <<< "$STUDENTS"

for student in "${STUDENT_ARRAY[@]}"; do
    echo ""
    echo -e "${YELLOW}Processing: $student${NC}"
    
    # Get student credentials
    STUDENT_DATA="${OUTPUT_DIR}/${student}/provision-user-data.yaml"
    if [ ! -f "$STUDENT_DATA" ]; then
        echo -e "${RED}  Error: Student data not found at $STUDENT_DATA${NC}"
        continue
    fi
    
    # Extract credentials
    BASTION_HOST=$(grep "bastion_public_hostname:" "$STUDENT_DATA" | awk '{print $2}')
    BASTION_PASSWORD=$(grep "bastion_ssh_password:" "$STUDENT_DATA" | awk '{print $2}')
    CONSOLE_URL=$(grep "openshift_console_url:" "$STUDENT_DATA" | awk '{print $2}')
    
    if [ -z "$BASTION_HOST" ] || [ -z "$BASTION_PASSWORD" ]; then
        echo -e "${RED}  Error: Could not extract credentials for $student${NC}"
        continue
    fi
    
    echo "  Bastion: $BASTION_HOST"
    echo "  Console: $CONSOLE_URL"
    
    DEPLOY_NAME="${student}-workshop"
    ROUTE_HOST="${DEPLOY_NAME}-${NAMESPACE}.${INGRESS_DOMAIN}"
    
    # Create ServiceAccount
    oc create serviceaccount ${DEPLOY_NAME} -n ${NAMESPACE} 2>/dev/null || true
    
    # Create ConfigMap for user data
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${DEPLOY_NAME}-userdata
  namespace: ${NAMESPACE}
data:
  user_data.yml: |
    bastion_public_hostname: ${BASTION_HOST}
    bastion_ssh_password: ${BASTION_PASSWORD}
    bastion_ssh_user_name: lab-user
    openshift_console_url: ${CONSOLE_URL}
    student_name: ${student}
EOF

    # Create ConfigMap for nginx proxy config (same as original Showroom)
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${DEPLOY_NAME}-proxy-config
  namespace: ${NAMESPACE}
data:
  nginx.conf: |
    events {
    }
    error_log /dev/stdout info;
    http {
      include /etc/nginx/mime.types;
      proxy_cache off;
      expires -1;
      proxy_cache_path /dev/null keys_zone=mycache:10m;
      map \$http_upgrade \$connection_upgrade {
          default upgrade;
          '' close;
      }
      server {
        listen 8080;
        absolute_redirect off;
        location / {
          index index.html;
          root /data/www;
        }
        location /content/ {
          proxy_pass http://localhost:8000;
          rewrite ^/content/(.*)\$ /\$1 break;
          expires off;
          proxy_cache off;
          proxy_pass_request_headers on;
          proxy_set_header Accept-Encoding "gzip";
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto \$scheme;
        }
        location ^~ /wetty {
          proxy_pass http://localhost:8001/wetty;
          proxy_http_version 1.1;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 43200000;
          proxy_set_header X-Real-IP \$remote_addr;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header Host \$http_host;
          proxy_set_header X-NginX-Proxy true;
        }
      }
    }
EOF

    # Create ConfigMap for index.html (same template as original Showroom)
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${DEPLOY_NAME}-index
  namespace: ${NAMESPACE}
data:
  index.html: |
    <!DOCTYPE html>
    <html>
      <head>
        <title>Low-Latency Workshop - ${student}</title>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8" />
        <link rel="stylesheet" type="text/css" href="split.css">
        <link rel="stylesheet" type="text/css" href="tabs.css">
      </head>
      <body>
        <div class="content">
          <div class="split left">
            <iframe id="doc" src="https://${ROUTE_HOST}/content" width="100%" style="border:none;"></iframe>
          </div>
          <div class="split right">
            <div class="tab">
              <button class="tablinks" onclick="openTerminal(event, 'wetty_tab1')" id="defaultOpen" tabindex="0">${student} Terminal</button>
            </div>
            <div id="wetty_tab1" class="tabcontent">
              <iframe id="terminal_01" src="https://${ROUTE_HOST}/wetty" width="100%" style="border:none;"></iframe>
            </div>
          </div>
        </div>
        <script>
          document.getElementById("defaultOpen").click();
          function openTerminal(evt, tabName) {
            var i, tabcontent, tablinks;
            tabcontent = document.getElementsByClassName("tabcontent");
            for (i = 0; i < tabcontent.length; i++) {
              tabcontent[i].style.display = "none";
            }
            tablinks = document.getElementsByClassName("tablinks");
            for (i = 0; i < tablinks.length; i++) {
              tablinks[i].className = tablinks[i].className.replace(" active", "");
            }
            document.getElementById(tabName).style.display = "block";
            evt.currentTarget.className += "active";
          }
        </script>
        <script src="https://unpkg.com/split.js/dist/split.min.js"></script>
        <script>
          Split(['.left', '.right'], { sizes: [45,55] });
          Split(['.top', '.bottom'], { sizes: [65,35], direction: 'vertical' });
        </script>
      </body>
    </html>
  split.css: |
    * { box-sizing: border-box; height:100%; }
    body { margin: 0; height:100%; }
    .content { width: 100%; height: 100%; padding: 0px; display: flex; justify-items: center; align-items: center; border-top: 1px solid; border-color: Gainsboro; border-top-width: thin; margin-top: 0px; }
    .split { width:100%; height:100%; padding: 5px; }
    .left { height: 100% }
    .right { height: 100% }
    .gutter { height: 98%; background-color: #eee; background-repeat: no-repeat; background-position: 50%; }
    .gutter.gutter-horizontal { background-image: url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAeCAYAAADkftS9AAAAIklEQVQoU2M4c+bMfxAGAgYYmwGrIIiDjrELjpo5aiZeMwF+yNnOs5KSvgAAAABJRU5ErkJggg=='); cursor: col-resize; }
    .gutter.gutter-vertical { background-image: url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAFAQMAAABo7865AAAABlBMVEVHcEzMzMzyAv2sAAAAAXRSTlMAQObYZgAAABBJREFUeF5jOAMEEAIEEFwAn3kMwcB6I2AAAAAASUVORK5CYII='); cursor: row-resize; }
  tabs.css: |
    .tab { overflow: hidden; border: 1px solid #ccc; background-color: #f1f1f1; height: 50px; }
    .tab button { background-color: inherit; float: left; border: none; outline: none; cursor: pointer; padding: 14px 16px; transition: 0.3s; }
    .tab button:hover { background-color: #ddd; }
    .tab button.active { background-color: #ccc; }
    .tabcontent { display: none; padding: 6px 12px; border: 1px solid #ccc; border-top: none; height: calc(100% - 50px); }
EOF

    # Create Deployment (matching original Showroom structure)
    cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${DEPLOY_NAME}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${DEPLOY_NAME}
    spec:
      serviceAccount: ${DEPLOY_NAME}
      serviceAccountName: ${DEPLOY_NAME}
      containers:
      - name: nginx
        image: quay.io/rhpds/nginx:1.25
        imagePullPolicy: IfNotPresent
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        ports:
        - containerPort: 8080
          name: web
        volumeMounts:
        - mountPath: /etc/nginx/nginx.conf
          name: nginx-config
          subPath: nginx.conf
        - mountPath: /data/www
          name: content
        - mountPath: /var/cache/nginx
          name: nginx-cache
        - mountPath: /var/run
          name: nginx-pid
      - name: content
        image: ghcr.io/rhpds/showroom-content:prod
        imagePullPolicy: IfNotPresent
        env:
        - name: GIT_REPO_URL
          value: "${CONTENT_REPO}"
        - name: GIT_REPO_REF
          value: "${CONTENT_REF}"
        - name: ANTORA_PLAYBOOK
          value: "default-site.yml"
        ports:
        - containerPort: 8000
        volumeMounts:
        - mountPath: /user_data/
          name: user-data
        - mountPath: /showroom/
          name: showroom
        livenessProbe:
          httpGet:
            path: /
            port: 8000
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8000
          periodSeconds: 10
      - name: wetty
        image: quay.io/rhpds/wetty:latest
        imagePullPolicy: IfNotPresent
        args:
        - --base="/wetty/"
        - --port=8001
        - --ssh-host=${BASTION_HOST}
        - --ssh-port=22
        - --ssh-user=lab-user
        - --ssh-auth=password
        - --ssh-pass=${BASTION_PASSWORD}
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: GUID
          value: "${student}"
        ports:
        - containerPort: 8001
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 50m
            memory: 256Mi
      volumes:
      - name: showroom
        emptyDir: {}
      - name: user-data
        configMap:
          name: ${DEPLOY_NAME}-userdata
      - name: content
        configMap:
          name: ${DEPLOY_NAME}-index
      - name: nginx-config
        configMap:
          name: ${DEPLOY_NAME}-proxy-config
      - name: nginx-pid
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
EOF

    # Create Service
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${DEPLOY_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app.kubernetes.io/name: ${DEPLOY_NAME}
  ports:
  - port: 8080
    targetPort: 8080
EOF

    # Create Route
    cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${DEPLOY_NAME}
  namespace: ${NAMESPACE}
spec:
  host: ${ROUTE_HOST}
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: ${DEPLOY_NAME}
  port:
    targetPort: 8080
EOF
    
    echo -e "${GREEN}  ✅ Deployed: https://${ROUTE_HOST}/${NC}"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Waiting for pods to be ready..."
sleep 5
oc get pods -n ${NAMESPACE}
echo ""
echo "Student Showroom URLs:"
for student in "${STUDENT_ARRAY[@]}"; do
    ROUTE_URL=$(oc get route ${student}-workshop -n ${NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$ROUTE_URL" ]; then
        echo -e "  ${GREEN}${student}${NC}: https://${ROUTE_URL}/"
    fi
done
