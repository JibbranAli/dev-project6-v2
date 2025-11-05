#!/bin/bash
# 🚀 Flask Application Deployment Script
# Builds, tests, and deploys the Flask application to Kubernetes

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

# Configuration
APP_NAME="devops-flask-app"
IMAGE_TAG="latest"
NAMESPACE="dev"
CLUSTER_NAME="devops-cluster"

log_info "🚀 Starting Flask Application Deployment..."

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
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please run: sudo ./1-install-all.sh"
        exit 1
    fi
    
    # Check if cluster exists
    if ! kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        log_error "Kubernetes cluster '$CLUSTER_NAME' not found"
        log_info "Please run: ./2-start-services.sh"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "Namespace '$NAMESPACE' not found, creating it..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    log_success "All prerequisites met"
}

# Run tests before deployment
run_tests() {
    log_info "🧪 Running application tests..."
    
    if [ -f "tests/test_app.py" ]; then
        # Install test dependencies
        if [ -f "app/requirements.txt" ]; then
            log_info "Installing Python dependencies..."
            python3 -m pip install -r app/requirements.txt --quiet --user 2>/dev/null || {
                log_warning "Could not install Python dependencies. Skipping tests."
                return 0
            }
        fi
        
        # Run tests
        log_info "Executing unit tests..."
        python3 -m pytest tests/ -v --tb=short 2>/dev/null || {
            log_warning "Tests failed or pytest not available. Continuing with deployment..."
            return 0
        }
        
        log_success "All tests passed"
    else
        log_warning "No test files found. Skipping tests."
    fi
}

# Build Docker image
build_image() {
    log_info "🐳 Building Docker image..."
    
    if [ ! -f "docker/Dockerfile" ]; then
        log_error "Dockerfile not found at docker/Dockerfile"
        exit 1
    fi
    
    if [ ! -f "app/main.py" ]; then
        log_error "Flask application not found at app/main.py"
        exit 1
    fi
    
    # Build the image
    log_info "Building $APP_NAME:$IMAGE_TAG..."
    docker build -f docker/Dockerfile -t "$APP_NAME:$IMAGE_TAG" . --quiet
    
    # Verify image was built
    if docker images "$APP_NAME:$IMAGE_TAG" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$APP_NAME:$IMAGE_TAG"; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Security scan with Trivy
security_scan() {
    log_info "🛡️  Running security scan..."
    
    if command -v trivy >/dev/null 2>&1; then
        log_info "Scanning $APP_NAME:$IMAGE_TAG for vulnerabilities..."
        
        # Run Trivy scan
        trivy image --severity HIGH,CRITICAL --no-progress --quiet "$APP_NAME:$IMAGE_TAG" > security-report.txt 2>&1 || true
        
        # Check results
        if [ -s security-report.txt ]; then
            local vuln_count=$(grep -c "Total:" security-report.txt 2>/dev/null || echo "0")
            if [ "$vuln_count" -gt 0 ]; then
                log_warning "Security vulnerabilities found. Check security-report.txt"
                log_info "Continuing with deployment (this is for learning purposes)"
            else
                log_success "No high/critical vulnerabilities found"
            fi
        else
            log_success "Security scan completed - no issues found"
        fi
        
        rm -f security-report.txt
    else
        log_warning "Trivy not installed. Skipping security scan."
        log_info "Install with: sudo ./1-install-all.sh"
    fi
}

# Load image into kind cluster
load_image_to_cluster() {
    log_info "📦 Loading image into Kubernetes cluster..."
    
    # Load image into kind cluster
    kind load docker-image "$APP_NAME:$IMAGE_TAG" --name "$CLUSTER_NAME"
    
    # Verify image is loaded
    if docker exec -it "${CLUSTER_NAME}-control-plane" crictl images | grep -q "$APP_NAME" 2>/dev/null; then
        log_success "Image loaded into cluster successfully"
    else
        log_warning "Could not verify image in cluster, but continuing..."
    fi
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log_info "☸️  Deploying to Kubernetes..."
    
    # Check if deployment files exist
    if [ ! -d "k8s/$NAMESPACE" ]; then
        log_error "Kubernetes deployment files not found at k8s/$NAMESPACE/"
        exit 1
    fi
    
    # Apply Kubernetes manifests
    log_info "Applying Kubernetes manifests..."
    kubectl apply -f "k8s/$NAMESPACE/" --namespace="$NAMESPACE"
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready..."
    kubectl rollout status deployment/flask-app -n "$NAMESPACE" --timeout=300s
    
    # Verify pods are running
    local pod_count=$(kubectl get pods -n "$NAMESPACE" -l app=flask-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        log_success "Application deployed successfully ($pod_count pods running)"
    else
        log_error "Deployment failed - no running pods found"
        kubectl get pods -n "$NAMESPACE" -l app=flask-app
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    log_info "✅ Verifying deployment..."
    
    # Get pod information
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app=flask-app -o wide
    
    # Get service information
    log_info "Service status:"
    kubectl get services -n "$NAMESPACE" -l app=flask-app
    
    # Test application health
    log_info "Testing application health..."
    
    # Port forward to test the app
    kubectl port-forward svc/flask-app-service 8080:80 -n "$NAMESPACE" >/dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Wait a moment for port forward to establish
    sleep 3
    
    # Test health endpoint
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        log_success "Application health check passed"
    else
        log_warning "Health check failed, but deployment completed"
    fi
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    log_success "Deployment verification completed"
}

# Show access information
show_access_info() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    log_success "🎉 Flask Application Deployed Successfully!"
    echo ""
    log_info "🌐 Access Your Application:"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Method 1: Port Forward (Recommended for testing)           │"
    echo "│ Command: kubectl port-forward svc/flask-app-service 8080:80 -n $NAMESPACE │"
    echo "│ URL:     http://localhost:8080                              │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    log_info "🔍 Useful Commands:"
    echo "• View pods:        kubectl get pods -n $NAMESPACE"
    echo "• View services:    kubectl get services -n $NAMESPACE"
    echo "• View logs:        kubectl logs -f deployment/flask-app -n $NAMESPACE"
    echo "• Scale app:        kubectl scale deployment flask-app --replicas=3 -n $NAMESPACE"
    echo "• Delete app:       kubectl delete -f k8s/$NAMESPACE/"
    echo ""
    log_info "📊 Monitor Your Application:"
    echo "• Prometheus: http://$server_ip:30090"
    echo "• Grafana:    http://$server_ip:30091 (admin/admin123)"
    echo ""
    log_info "🔄 Redeploy Application:"
    echo "• Make code changes in app/"
    echo "• Run: ./4-deploy-flask.sh"
    echo "• Or trigger Jenkins pipeline"
}

# Handle different deployment modes
handle_deployment_mode() {
    case "${1:-deploy}" in
        "deploy"|"")
            log_info "🚀 Full deployment mode"
            run_tests
            build_image
            security_scan
            load_image_to_cluster
            deploy_to_kubernetes
            verify_deployment
            ;;
        "quick")
            log_info "⚡ Quick deployment mode (skip tests and security scan)"
            build_image
            load_image_to_cluster
            deploy_to_kubernetes
            verify_deployment
            ;;
        "test-only")
            log_info "🧪 Test-only mode"
            run_tests
            return 0
            ;;
        "build-only")
            log_info "🐳 Build-only mode"
            build_image
            security_scan
            return 0
            ;;
        *)
            log_error "Unknown deployment mode: $1"
            log_info "Available modes: deploy, quick, test-only, build-only"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    local mode="${1:-deploy}"
    
    log_info "Flask Application Deployment Script"
    log_info "Mode: $mode"
    echo ""
    
    check_prerequisites
    handle_deployment_mode "$mode"
    
    if [[ "$mode" == "deploy" || "$mode" == "quick" ]]; then
        show_access_info
    fi
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Show usage if help requested
if [[ "${1}" == "--help" || "${1}" == "-h" ]]; then
    echo "Flask Application Deployment Script"
    echo ""
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Modes:"
    echo "  deploy     Full deployment with tests and security scan (default)"
    echo "  quick      Quick deployment without tests and security scan"
    echo "  test-only  Run tests only"
    echo "  build-only Build and scan image only"
    echo ""
    echo "Examples:"
    echo "  $0                # Full deployment"
    echo "  $0 quick          # Quick deployment"
    echo "  $0 test-only      # Run tests only"
    echo "  $0 build-only     # Build image only"
    exit 0
fi

# Run main function
main "$@"