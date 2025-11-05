#!/bin/bash
# 🚀 DevOps Services Starter
# Creates Kubernetes cluster and deploys all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

log_info "🚀 Starting DevOps Services..."

# Check prerequisites
check_prerequisites() {
    log_info "🔍 Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v kind >/dev/null 2>&1; then
        missing_tools+=("kind")
    fi
    
    if ! command -v helm >/dev/null 2>&1; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please run: sudo ./1-install-all.sh"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker service."
        log_info "Run: sudo systemctl start docker"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create Kubernetes cluster
create_cluster() {
    if kind get clusters 2>/dev/null | grep -q devops-cluster; then
        log_success "Kubernetes cluster already exists"
        return
    fi
    
    log_info "📦 Creating Kubernetes cluster with kind..."
    
    # Create cluster configuration
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
  - containerPort: 30091
    hostPort: 30091
    protocol: TCP
- role: worker
- role: worker
EOF
    
    # Create cluster
    kind create cluster --config kind-config.yaml --name devops-cluster
    rm kind-config.yaml
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Kubernetes cluster created successfully"
}

# Create namespaces
create_namespaces() {
    log_info "📦 Creating namespaces..."
    
    namespaces=("dev" "prod" "argocd" "monitoring")
    
    for ns in "${namespaces[@]}"; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
        log_info "Created namespace: $ns"
    done
    
    log_success "All namespaces created"
}

# Install ArgoCD
install_argocd() {
    log_info "📦 Installing ArgoCD..."
    
    # Check if ArgoCD is already installed
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_success "ArgoCD already installed"
    else
        # Install ArgoCD
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD to be ready
        log_info "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    fi
    
    # Expose ArgoCD service
    kubectl patch svc argocd-server -n argocd --type='json' -p='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}, {"op": "replace", "path": "/spec/ports/0/nodePort", "value": 30080}]' >/dev/null 2>&1 || true
    
    # Get ArgoCD password
    log_info "Getting ArgoCD credentials..."
    sleep 10  # Wait for secret to be created
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "password-not-ready")
    
    if [ "$ARGOCD_PASSWORD" != "password-not-ready" ]; then
        echo "ArgoCD Admin Password: $ARGOCD_PASSWORD" > argocd-credentials.txt
        log_success "ArgoCD installed successfully"
    else
        log_warning "ArgoCD password not ready yet. Check later with:"
        log_warning "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    fi
}

# Install monitoring stack
install_monitoring() {
    log_info "📦 Installing monitoring stack (Prometheus & Grafana)..."
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1
    
    # Check if monitoring stack is already installed
    if helm list -n monitoring | grep -q prometheus; then
        log_success "Monitoring stack already installed"
        return
    fi
    
    # Install Prometheus and Grafana
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=30090 \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30091 \
        --set grafana.adminPassword=admin123 \
        --timeout=600s
    
    # Wait for monitoring stack to be ready
    log_info "Waiting for monitoring stack to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/prometheus-grafana -n monitoring
    
    log_success "Monitoring stack installed successfully"
}

# Build and deploy Flask application
deploy_application() {
    log_info "📦 Building and deploying Flask application..."
    
    # Build Docker image
    log_info "Building Docker image..."
    docker build -f docker/Dockerfile -t devops-flask-app:latest . --quiet
    
    # Load image into kind cluster
    log_info "Loading image into cluster..."
    kind load docker-image devops-flask-app:latest --name devops-cluster
    
    # Deploy to development environment
    log_info "Deploying to development environment..."
    kubectl apply -f k8s/dev/
    
    # Wait for deployment to be ready
    log_info "Waiting for application to be ready..."
    kubectl rollout status deployment/flask-app -n dev --timeout=300s
    
    log_success "Application deployed successfully"
}

# Deploy ArgoCD applications
deploy_argocd_apps() {
    log_info "📦 Deploying ArgoCD applications..."
    
    # Apply ArgoCD application configurations
    if [ -f argocd/application-dev.yaml ]; then
        kubectl apply -f argocd/application-dev.yaml
        log_info "Development ArgoCD application deployed"
    fi
    
    if [ -f argocd/application-prod.yaml ]; then
        kubectl apply -f argocd/application-prod.yaml
        log_info "Production ArgoCD application deployed"
    fi
    
    log_success "ArgoCD applications configured"
}

# Display access information
show_access_info() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    log_success "🎉 All services started successfully!"
    echo ""
    log_info "🌐 Service Access URLs:"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Service    │ URL                                            │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ Jenkins    │ http://${server_ip}:8080                       │"
    echo "│ ArgoCD     │ http://${server_ip}:30080                      │"
    echo "│ Prometheus │ http://${server_ip}:30090                      │"
    echo "│ Grafana    │ http://${server_ip}:30091                      │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    log_info "🔑 Default Credentials:"
    echo "• Jenkins:    admin / (check jenkins-credentials.txt)"
    echo "• ArgoCD:     admin / (check argocd-credentials.txt)"
    echo "• Grafana:    admin / admin123"
    echo ""
    log_info "🚀 Access Flask Application:"
    echo "kubectl port-forward svc/flask-app-service 8080:80 -n dev"
    echo "Then visit: http://localhost:8080"
    echo ""
    log_info "📋 Next Steps:"
    echo "1. Configure Jenkins: http://${server_ip}:8080"
    echo "2. Run: ./3-create-pipeline.sh"
    echo "3. Start developing!"
    echo ""
    log_info "🔍 Useful Commands:"
    echo "• Check pods: kubectl get pods --all-namespaces"
    echo "• Check services: kubectl get services --all-namespaces"
    echo "• View logs: kubectl logs -f deployment/flask-app -n dev"
}

# Main execution
main() {
    check_prerequisites
    create_cluster
    create_namespaces
    install_argocd
    install_monitoring
    deploy_application
    deploy_argocd_apps
    show_access_info
}

# Run main function
main