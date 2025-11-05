#!/bin/bash

# Local Jenkins-based deployment script
ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

echo "Deploying to $ENVIRONMENT environment using Jenkins pipeline..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Build and load image to kind cluster
log "Building Docker image..."
docker build -f docker/Dockerfile -t devops-flask-app:$IMAGE_TAG .

log "Loading image to kind cluster..."
kind load docker-image devops-flask-app:$IMAGE_TAG --name devops-cluster

# Update deployment manifest
log "Updating Kubernetes manifests..."
sed -i "s|image: devops-flask-app:.*|image: devops-flask-app:$IMAGE_TAG|g" k8s/$ENVIRONMENT/deployment.yaml

# Ensure imagePullPolicy is Never for local images
if ! grep -q "imagePullPolicy: Never" k8s/$ENVIRONMENT/deployment.yaml; then
    sed -i '/image: devops-flask-app:/a\        imagePullPolicy: Never' k8s/$ENVIRONMENT/deployment.yaml
fi

# Apply Kubernetes manifests
log "Applying Kubernetes manifests..."
kubectl apply -f k8s/$ENVIRONMENT/

# Wait for deployment to be ready
log "Waiting for deployment to be ready..."
kubectl rollout status deployment/flask-app -n $ENVIRONMENT --timeout=300s

# Verify deployment
log "Verifying deployment..."
kubectl get pods -n $ENVIRONMENT -l app=flask-app
kubectl get svc -n $ENVIRONMENT

log "Deployment to $ENVIRONMENT completed successfully!"
log ""
log "Access the application:"
log "kubectl port-forward svc/flask-app-service 8080:80 -n $ENVIRONMENT"
log "Then visit: http://localhost:8080/health"