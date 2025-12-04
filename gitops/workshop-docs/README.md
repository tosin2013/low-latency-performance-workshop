# Workshop Documentation - OpenShift BuildConfig

This directory contains the resources for building personalized workshop documentation using OpenShift BuildConfig and ImageStream.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Per User Namespace (workshop-user1)                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  BuildConfig                      ImageStream                       │
│  ┌─────────────────────┐         ┌─────────────────────┐           │
│  │ workshop-docs       │ ──────► │ workshop-docs:latest│           │
│  │                     │ builds  │                     │           │
│  │ - Clones repo       │         └──────────┬──────────┘           │
│  │ - Runs Dockerfile   │                    │                       │
│  │ - Injects user vars │                    │ triggers              │
│  └─────────────────────┘                    ▼                       │
│                                   ┌─────────────────────┐           │
│                                   │ Deployment          │           │
│                                   │ workshop-docs       │           │
│                                   │                     │           │
│                                   │ (httpd serving      │           │
│                                   │  pre-built Antora)  │           │
│                                   └──────────┬──────────┘           │
│                                              │                       │
│                                              ▼                       │
│                                   ┌─────────────────────┐           │
│                                   │ Route               │           │
│                                   │ docs-user1          │           │
│                                   │                     │           │
│                                   │ https://docs-user1. │           │
│                                   │ apps.{domain}       │           │
│                                   └─────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

## How It Works

1. **BuildConfig** clones the workshop repo and runs the Dockerfile
2. **Dockerfile** (multi-stage):
   - Stage 1: Uses `antora/antora` to build personalized docs with user-specific variables
   - Stage 2: Copies built docs into `ubi9/httpd-24` image
3. **ImageStream** stores the built image
4. **Deployment** uses the ImageStream (auto-updates when new builds complete)
5. **Route** exposes docs at `https://docs-{username}.apps.{domain}`

## Build Arguments

The BuildConfig injects these user-specific variables:

| Arg | Description | Example |
|-----|-------------|---------|
| `USER_NAME` | Workshop username | `user1` |
| `SNO_GUID` | SNO cluster identifier | `workshop-user1` |
| `SNO_API_URL` | SNO API endpoint | `https://api.workshop-user1.example.com:6443` |
| `SNO_CONSOLE_URL` | SNO console URL | `https://console-openshift-console.apps.workshop-user1.example.com` |
| `BASTION_HOST` | Bastion hostname | `bastion.workshop-user1.example.com` |
| `SUBDOMAIN_SUFFIX` | Domain suffix | `.sandbox1234.opentlc.com` |

## Manual Testing

```bash
# Apply to a test namespace
oc new-project workshop-test

# Apply base resources
oc apply -k gitops/workshop-docs/base

# Start a build with custom args
oc start-build workshop-docs \
  --build-arg USER_NAME=testuser \
  --build-arg SNO_GUID=workshop-testuser \
  --build-arg SNO_API_URL=https://api.test.example.com:6443 \
  --build-arg SNO_CONSOLE_URL=https://console.test.example.com \
  --build-arg BASTION_HOST=bastion.test.example.com \
  --build-arg SUBDOMAIN_SUFFIX=.example.com

# Watch build
oc logs -f bc/workshop-docs

# Check deployment
oc get pods
oc get route
```

## Rebuilding Docs

To rebuild docs for a user (e.g., after repo updates):

```bash
# Trigger new build
oc start-build workshop-docs -n workshop-user1

# Or delete the build to trigger ConfigChange
oc delete build -l buildconfig=workshop-docs -n workshop-user1
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build for Antora docs |
| `base/buildconfig.yaml` | BuildConfig template |
| `base/imagestream.yaml` | ImageStream for built images |
| `base/deployment.yaml` | Deployment using ImageStream |
| `base/service.yaml` | Service for httpd |
| `base/route.yaml` | Route for external access |
| `base/kustomization.yaml` | Kustomize config |

