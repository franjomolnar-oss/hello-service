# ArgoCD Deployment Guide for hello-service

This guide explains how to set up and use ArgoCD for GitOps-based deployments of the hello-service project.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. Instead of imperatively deploying applications via Helm commands, ArgoCD watches your Git repository and automatically syncs your Kubernetes cluster to match the desired state defined in Git.

## Benefits of ArgoCD

- **GitOps**: Your entire infrastructure is version-controlled in Git
- **Automatic Sync**: Cluster automatically stays in sync with Git state
- **Self-Healing**: Automatically fixes drift from desired state
- **Audit Trail**: Every change is tracked in Git history
- **Single Source of Truth**: Git repository is the authoritative source
- **Multi-Environment**: Manage staging and production in separate Applications

## Prerequisites

- Kubernetes cluster (1.16+)
- kubectl configured with access to your cluster
- Git repository with hello-service code

## Installation

### Option 1: Automatic Setup (Recommended)

Run the setup script:

```bash
chmod +x argocd/setup-argocd.sh
./argocd/setup-argocd.sh
```

### Option 2: Manual Setup

1. Create ArgoCD namespace:
```bash
kubectl create namespace argocd
```

2. Install ArgoCD:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/release-2.8/manifests/install.yaml
```

3. Wait for ArgoCD to be ready:
```bash
kubectl wait -n argocd --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s
```

## Deploying Applications

### Deploying to Staging

```bash
kubectl apply -f argocd/app-staging.yaml
```

### Deploying to Production

```bash
kubectl apply -f argocd/app-production.yaml
```

## Accessing ArgoCD UI

### Port Forward (Local Development)

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Access: `https://localhost:8080`

### Login

- **Username**: admin
- **Password**: Get from initial secret
  ```bash
  kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## Application Configuration

### Staging Application (`app-staging.yaml`)
- **Replicas**: 2
- **Resources**: CPU 100m-200m, Memory 64-128Mi
- **Environment**: staging
- **Auto-Sync**: Enabled

### Production Application (`app-production.yaml`)
- **Replicas**: 3
- **Resources**: CPU 200m-500m, Memory 128-256Mi
- **Environment**: production
- **Auto-Sync**: Enabled

## Syncing Applications

### Automatic Sync
Applications are configured with automatic sync enabled. Changes in Git are automatically applied to the cluster.

### Manual Sync via ArgoCD CLI

1. Install ArgoCD CLI:
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd
```

2. Login:
```bash
argocd login localhost:6443 --grpc-web
```

3. Sync application:
```bash
argocd app sync hello-service-staging
argocd app sync hello-service-production
```

### Manual Sync via kubectl

```bash
kubectl patch application hello-service-staging -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Monitoring Deployments

### View Application Status

```bash
kubectl get applications -n argocd

# Detailed info
kubectl describe application hello-service-staging -n argocd
```

### Watch Sync Progress

```bash
kubectl logs -n argocd deployment/argocd-application-controller -f
```

## Jenkins Integration

The Jenkinsfile is integrated with ArgoCD:

1. **Register ArgoCD Application**: Creates/updates the ArgoCD Application resource
2. **Deploy with ArgoCD**: Triggers sync with updated image tag
3. **Verify Deployment**: Checks Kubernetes deployment status
4. **Health Check**: Validates application health endpoints

## Updating Application Images

To update the image tag for both staging and production:

1. Push image to registry
2. Update the image tag in Jenkins parameters (IMAGE_TAG parameter)
3. Jenkins will automatically:
   - Register/update ArgoCD Application
   - Trigger ArgoCD sync with new image tag
   - Verify deployment
   - Run health checks

## Troubleshooting

### Application stuck in "Progressing" state

```bash
# Check ArgoCD application status
kubectl describe application hello-service-staging -n argocd

# Check application logs
kubectl logs -n staging deployment/hello-service
```

### Out of Sync after deployment

```bash
# Force hard refresh
kubectl patch application hello-service-staging -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Cannot sync due to permission errors

Ensure ArgoCD has RBAC permissions for your namespaces:

```bash
kubectl create rolebinding argocd-deployment -n staging \
  --clusterrole=admin \
  --serviceaccount=argocd:argocd-application-controller
```

## Best Practices

1. **Use separate Applications for each environment** ✅ Done
2. **Enable automatic sync for consistency** ✅ Configured
3. **Configure self-healing** ✅ Enabled
4. **Use Git tags for production releases** Consider adding
5. **Monitor ArgoCD events** Set up Prometheus monitoring
6. **Keep Helm values in Git** ✅ ArgoCD manifests define values

## References

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.weave.works/technologies/gitops/)
- [Helm Integration with ArgoCD](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
