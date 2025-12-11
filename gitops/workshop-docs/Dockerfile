# Multi-stage build for personalized workshop documentation
# Stage 1: Build Antora docs with user-specific variables
# Using the same image as GitHub Actions workflow for consistency
FROM ghcr.io/rhpds/showroom-content:latest AS builder

# Build arguments for user customization
ARG USER_NAME=user1
ARG SNO_GUID=workshop-user1
ARG SNO_API_URL=https://api.workshop-user1.example.com:6443
ARG SNO_CONSOLE_URL=https://console-openshift-console.apps.workshop-user1.example.com
ARG BASTION_HOST=bastion.workshop-user1.example.com
ARG SUBDOMAIN_SUFFIX=.example.com
ARG HUB_APPS_DOMAIN=apps.cluster.example.com

# Switch to root to handle permissions
USER root

# Copy the workshop content to a writable directory
WORKDIR /build
COPY . .

# Initialize git repository (required by Antora for local content sources)
RUN git init && \
    git config user.email "build@local" && \
    git config user.name "Build" && \
    git add -A && \
    git commit -m "Build commit"

# Update antora.yml with user-specific values
RUN sed -i "s|guid:.*|guid: ${SNO_GUID}|g" content/antora.yml && \
    sed -i "s|cluster_api:.*|cluster_api: ${SNO_API_URL}|g" content/antora.yml && \
    sed -i "s|cluster_console:.*|cluster_console: ${SNO_CONSOLE_URL}|g" content/antora.yml && \
    sed -i "s|bastion_host:.*|bastion_host: ${BASTION_HOST}|g" content/antora.yml && \
    sed -i "s|student_name:.*|student_name: ${USER_NAME}|g" content/antora.yml && \
    sed -i "s|username:.*|username: ${USER_NAME}|g" content/antora.yml && \
    sed -i "s|subdomain:.*|subdomain: ${SUBDOMAIN_SUFFIX#.}|g" content/antora.yml && \
    sed -i "s|devspaces_url:.*|devspaces_url: https://devspaces.${HUB_APPS_DOMAIN}|g" content/antora.yml && \
    sed -i "s|devspaces_factory:.*|devspaces_factory: https://devspaces.${HUB_APPS_DOMAIN}/dashboard/#/load-factory?url=https://github.com/tosin2013/low-latency-performance-workshop|g" content/antora.yml && \
    echo "Building docs for user: ${USER_NAME}, GUID: ${SNO_GUID}" && \
    git add content/antora.yml && \
    git commit -m "Update with user-specific values" --allow-empty

# Build the Antora site (same command as GitHub workflow)
RUN mkdir -p output && \
    antora --stacktrace --to-dir=output default-site.yml || \
    (echo "Antora build failed, creating placeholder" && \
     mkdir -p output && \
     echo "<html><body><h1>Workshop Docs for ${USER_NAME}</h1><p>Antora build failed. Check build logs.</p></body></html>" > output/index.html)

# Stage 2: Serve with nginx (simpler, no SSL issues)
FROM image-registry.openshift-image-registry.svc:5000/openshift/nginx:1.22-ubi8

# Copy built docs from builder stage  
COPY --from=builder /build/output /opt/app-root/src/

# Labels
LABEL io.k8s.display-name="Low-Latency Workshop Docs" \
      io.k8s.description="Personalized workshop documentation" \
      io.openshift.tags="workshop,documentation,antora"

# nginx runs on port 8080 by default in UBI
EXPOSE 8080

# Use default nginx command
CMD ["nginx", "-g", "daemon off;"]

