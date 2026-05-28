#!/bin/bash

# ArgoCD Setup Script for hello-service
# This script helps set up ArgoCD for the hello-service project

set -e

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v2.8.0"

echo "🚀 Setting up ArgoCD for hello-service..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Create argocd namespace
echo "📦 Creating ArgoCD namespace..."
kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/release-2.8/manifests/install.yaml || true

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait -n $ARGOCD_NAMESPACE --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s || true

# Get ArgoCD initial password
echo ""
echo "🔑 ArgoCD Setup Complete!"
echo ""
echo "Initial admin password:"
kubectl get secret -n $ARGOCD_NAMESPACE argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# Port forward for local access
echo "🌐 To access ArgoCD UI locally, run:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
echo "Then access: https://localhost:8080"
echo "Username: admin"
echo "Password: (see above)"
echo ""

echo "✅ ArgoCD setup complete!"
