#!/bin/bash

# Rollback script for Kubernetes deployments
ENVIRONMENT=${1:-dev}
REVISION=${2:-}

if [ -z "$REVISION" ]; then
    echo "Usage: $0 <environment> [revision]"
    echo "Example: $0 dev 2"
    echo ""
    echo "Available revisions:"
    kubectl rollout history deployment/flask-app -n $ENVIRONMENT
    exit 1
fi

echo "Rolling back flask-app in $ENVIRONMENT to revision $REVISION..."

# Rollback deployment
kubectl rollout undo deployment/flask-app -n $ENVIRONMENT --to-revision=$REVISION

# Wait for rollback to complete
kubectl rollout status deployment/flask-app -n $ENVIRONMENT --timeout=300s

if [ $? -eq 0 ]; then
    echo "✅ Rollback completed successfully!"
    
    # Verify health
    echo "Checking application health..."
    sleep 10
    
    SERVICE_URL=$(kubectl get svc flask-app-service -n $ENVIRONMENT -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$SERVICE_URL" ]; then
        curl -f http://$SERVICE_URL/health || echo "⚠️  Health check failed"
    else
        echo "⚠️  Could not determine service URL for health check"
    fi
else
    echo "❌ Rollback failed!"
    exit 1
fi