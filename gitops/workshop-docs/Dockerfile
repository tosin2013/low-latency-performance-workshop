# Multi-stage build for personalized workshop documentation
# Stage 1: Build Antora docs with user-specific variables
FROM docker.io/antora/antora:latest AS builder

# Build arguments for user customization
ARG USER_NAME=user1
ARG SNO_GUID=workshop-user1
ARG SNO_API_URL=https://api.workshop-user1.example.com:6443
ARG SNO_CONSOLE_URL=https://console-openshift-console.apps.workshop-user1.example.com
ARG BASTION_HOST=bastion.workshop-user1.example.com
ARG SUBDOMAIN_SUFFIX=.example.com

# Copy the workshop content
WORKDIR /antora
COPY . .

# Update antora.yml with user-specific values
RUN sed -i "s|guid:.*|guid: ${SNO_GUID}|g" content/antora.yml && \
    sed -i "s|cluster_api:.*|cluster_api: ${SNO_API_URL}|g" content/antora.yml && \
    sed -i "s|cluster_console:.*|cluster_console: ${SNO_CONSOLE_URL}|g" content/antora.yml && \
    sed -i "s|bastion_host:.*|bastion_host: ${BASTION_HOST}|g" content/antora.yml && \
    sed -i "s|student_name:.*|student_name: ${USER_NAME}|g" content/antora.yml && \
    echo "Building docs for user: ${USER_NAME}, GUID: ${SNO_GUID}"

# Build the Antora site
RUN antora --stacktrace default-site.yml || \
    (echo "Antora build failed, creating placeholder" && \
     mkdir -p www && \
     echo "<html><body><h1>Workshop Docs for ${USER_NAME}</h1><p>Build in progress...</p></body></html>" > www/index.html)

# Stage 2: Serve with nginx (simpler, no SSL issues)
FROM registry.access.redhat.com/ubi9/nginx-124:1-18

# Copy built docs from builder stage
COPY --from=builder /antora/www /usr/share/nginx/html/

# Labels
LABEL io.k8s.display-name="Low-Latency Workshop Docs" \
      io.k8s.description="Personalized workshop documentation" \
      io.openshift.tags="workshop,documentation,antora"

# nginx runs on port 8080 by default in UBI
EXPOSE 8080

# Use default nginx command
CMD ["nginx", "-g", "daemon off;"]

