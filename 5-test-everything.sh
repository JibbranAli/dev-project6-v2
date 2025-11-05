#!/bin/bash
# 🧪 Complete System Testing Script
# Tests all components of the DevOps pipeline

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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Helper function to run test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name - PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name - FAILED"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

log_info "🧪 Starting Complete System Tests..."
echo ""

# Test 1: Docker Installation and Service
log_info "🐳 Testing Docker..."
run_test "Docker Installation" "command -v docker"
run_test "Docker Service Running" "docker info"
run_test "Docker Hello World" "docker run --rm hello-world"

echo ""

# Test 2: Kubernetes Tools
log_info "☸️  Testing Kubernetes Tools..."
run_test "kubectl Installation" "command -v kubectl"
run_test "kind Installation" "command -v kind"
run_test "Helm Installation" "command -v helm"

echo ""

# Test 3: Kubernetes Cluster
log_info "🎯 Testing Kubernetes Cluster..."
run_test "Kind Cluster Exists" "kind get clusters | grep -q devops-cluster"
run_test "Kubectl Cluster Access" "kubectl cluster-info"
run_test "Cluster Nodes Ready" "kubectl get nodes --no-headers | grep -q Ready"

echo ""

# Test 4: Namespaces
log_info "📁 Testing Namespaces..."
run_test "Dev Namespace" "kubectl get namespace dev"
run_test "Prod Namespace" "kubectl get namespace prod"
run_test "ArgoCD Namespace" "kubectl get namespace argocd"
run_test "Monitoring Namespace" "kubectl get namespace monitoring"

echo ""

# Test 5: Jenkins
log_info "🔧 Testing Jenkins..."
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
run_test "Jenkins Service Running" "systemctl is-active jenkins"
run_test "Jenkins Web Interface" "curl -s http://$SERVER_IP:8080/login"
run_test "Jenkins Credentials File" "test -f jenkins-credentials.txt"

echo ""

# Test 6: ArgoCD
log_info "🔄 Testing ArgoCD..."
run_test "ArgoCD Server Deployment" "kubectl get deployment argocd-server -n argocd"
run_test "ArgoCD Server Running" "kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running"
run_test "ArgoCD Web Interface" "curl -s -k http://$SERVER_IP:30080"
run_test "ArgoCD Credentials File" "test -f argocd-credentials.txt"

echo ""

# Test 7: Monitoring Stack
log_info "📊 Testing Monitoring Stack..."
run_test "Prometheus Deployment" "kubectl get deployment prometheus-kube-prometheus-prometheus -n monitoring"
run_test "Grafana Deployment" "kubectl get deployment prometheus-grafana -n monitoring"
run_test "Prometheus Web Interface" "curl -s http://$SERVER_IP:30090"
run_test "Grafana Web Interface" "curl -s http://$SERVER_IP:30091"

echo ""

# Test 8: Flask Application
log_info "🌐 Testing Flask Application..."
run_test "Flask App Deployment" "kubectl get deployment flask-app -n dev"
run_test "Flask App Pods Running" "kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running"
run_test "Flask App Service" "kubectl get service flask-app-service -n dev"

# Test Flask app endpoints
if kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running --no-headers | grep -q flask-app; then
    log_info "Testing Flask application endpoints..."
    
    # Start port forward in background
    kubectl port-forward svc/flask-app-service 8080:80 -n dev >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait for port forward to establish
    sleep 3
    
    # Test endpoints
    run_test "Flask Health Endpoint" "curl -s http://localhost:8080/health"
    run_test "Flask API Endpoint" "curl -s http://localhost:8080/api/users"
    run_test "Flask Root Endpoint" "curl -s http://localhost:8080/"
    
    # Clean up port forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
else
    log_warning "Flask app not running, skipping endpoint tests"
fi

echo ""

# Test 9: Security Tools
log_info "🛡️  Testing Security Tools..."
run_test "Trivy Installation" "command -v trivy"
if command -v trivy >/dev/null 2>&1; then
    run_test "Trivy Image Scan" "trivy image --quiet --no-progress alpine:latest"
fi

echo ""

# Test 10: Docker Images
log_info "🖼️  Testing Docker Images..."
run_test "Flask App Image Built" "docker images devops-flask-app:latest --format 'table {{.Repository}}:{{.Tag}}' | grep -q devops-flask-app:latest"
run_test "Flask App Image in Cluster" "docker exec devops-cluster-control-plane crictl images | grep -q devops-flask-app"

echo ""

# Test 11: Network Connectivity
log_info "🌐 Testing Network Connectivity..."
run_test "Internet Connectivity" "curl -s --connect-timeout 5 https://google.com"
run_test "Docker Hub Connectivity" "curl -s --connect-timeout 5 https://hub.docker.com"
run_test "GitHub Connectivity" "curl -s --connect-timeout 5 https://github.com"

echo ""

# Test 12: File Structure
log_info "📁 Testing Project Structure..."
run_test "Flask App Files" "test -f app/main.py && test -f app/requirements.txt"
run_test "Docker Files" "test -f docker/Dockerfile && test -f docker/docker-compose.yml"
run_test "Kubernetes Files" "test -d k8s/dev && test -d k8s/prod"
run_test "Jenkins Files" "test -f jenkins/Jenkinsfile"
run_test "ArgoCD Files" "test -d argocd"
run_test "Monitoring Files" "test -d monitoring"
run_test "Test Files" "test -d tests"

echo ""

# Test 13: Resource Usage
log_info "💾 Testing Resource Usage..."
run_test "Sufficient Disk Space" "[ $(df / | tail -1 | awk '{print $4}') -gt 1000000 ]"  # 1GB free
run_test "Sufficient Memory" "[ $(free -m | grep '^Mem:' | awk '{print $7}') -gt 500 ]"  # 500MB available
run_test "Docker Daemon Memory" "docker system df"

echo ""

# Test 14: Port Availability
log_info "🔌 Testing Port Availability..."
run_test "Jenkins Port (8080)" "netstat -tlnp 2>/dev/null | grep -q :8080 || ss -tlnp 2>/dev/null | grep -q :8080"
run_test "ArgoCD Port (30080)" "netstat -tlnp 2>/dev/null | grep -q :30080 || ss -tlnp 2>/dev/null | grep -q :30080"
run_test "Prometheus Port (30090)" "netstat -tlnp 2>/dev/null | grep -q :30090 || ss -tlnp 2>/dev/null | grep -q :30090"
run_test "Grafana Port (30091)" "netstat -tlnp 2>/dev/null | grep -q :30091 || ss -tlnp 2>/dev/null | grep -q :30091"

echo ""

# Performance Tests
log_info "⚡ Running Performance Tests..."

# Test Flask app response time
if kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running --no-headers | grep -q flask-app; then
    kubectl port-forward svc/flask-app-service 8080:80 -n dev >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 3
    
    # Measure response time
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:8080/health 2>/dev/null || echo "999")
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0") )); then
        log_success "Flask Response Time: ${RESPONSE_TIME}s - PASSED"
        ((TESTS_PASSED++))
    else
        log_warning "Flask Response Time: ${RESPONSE_TIME}s - SLOW"
        ((TESTS_FAILED++))
    fi
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

echo ""

# Generate Test Report
generate_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=0
    
    if [ $total_tests -gt 0 ]; then
        success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    fi
    
    echo "════════════════════════════════════════════════════════════════"
    log_info "📋 TEST REPORT SUMMARY"
    echo "════════════════════════════════════════════════════════════════"
    echo "Total Tests:    $total_tests"
    echo "Passed:         $TESTS_PASSED"
    echo "Failed:         $TESTS_FAILED"
    echo "Success Rate:   $success_rate%"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "🎉 ALL TESTS PASSED! Your DevOps pipeline is working perfectly!"
    else
        log_warning "⚠️  Some tests failed. See details below:"
        echo ""
        log_error "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        echo ""
        log_info "💡 Troubleshooting Tips:"
        echo "1. Check if all services are running: ./check-status.sh"
        echo "2. Restart services: ./2-start-services.sh"
        echo "3. Check logs: kubectl logs -f deployment/<service-name> -n <namespace>"
        echo "4. Verify installation: sudo ./1-install-all.sh"
    fi
    
    echo ""
    log_info "🔍 Detailed System Information:"
    echo "OS: $(uname -a)"
    echo "Docker: $(docker --version 2>/dev/null || echo 'Not installed')"
    echo "Kubectl: $(kubectl version --client --short 2>/dev/null || echo 'Not installed')"
    echo "Kind: $(kind version 2>/dev/null || echo 'Not installed')"
    echo "Helm: $(helm version --short 2>/dev/null || echo 'Not installed')"
    
    # Save report to file
    {
        echo "DevOps Pipeline Test Report - $(date)"
        echo "Total Tests: $total_tests"
        echo "Passed: $TESTS_PASSED"
        echo "Failed: $TESTS_FAILED"
        echo "Success Rate: $success_rate%"
        echo ""
        echo "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "- $test"
        done
    } > test-report.txt
    
    log_info "📄 Test report saved to: test-report.txt"
}

# Quick health check function
quick_health_check() {
    log_info "🏥 Quick Health Check..."
    
    # Essential services
    local essential_tests=(
        "Docker Service:docker info"
        "Kubernetes Cluster:kubectl cluster-info"
        "Flask App:kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running"
        "Jenkins:curl -s http://localhost:8080/login"
    )
    
    for test_item in "${essential_tests[@]}"; do
        local name="${test_item%%:*}"
        local command="${test_item##*:}"
        run_test "$name" "$command"
    done
}

# Main execution
main() {
    local mode="${1:-full}"
    
    case "$mode" in
        "full"|"")
            log_info "Running full system tests..."
            ;;
        "quick")
            log_info "Running quick health check..."
            quick_health_check
            generate_report
            return 0
            ;;
        "app-only")
            log_info "Testing Flask application only..."
            # Run only Flask app tests
            log_info "🌐 Testing Flask Application..."
            run_test "Flask App Deployment" "kubectl get deployment flask-app -n dev"
            run_test "Flask App Pods Running" "kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running"
            generate_report
            return 0
            ;;
        *)
            log_error "Unknown test mode: $mode"
            log_info "Available modes: full, quick, app-only"
            exit 1
            ;;
    esac
    
    generate_report
}

# Show usage if help requested
if [[ "${1}" == "--help" || "${1}" == "-h" ]]; then
    echo "Complete System Testing Script"
    echo ""
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Modes:"
    echo "  full       Run all tests (default)"
    echo "  quick      Quick health check of essential services"
    echo "  app-only   Test Flask application only"
    echo ""
    echo "Examples:"
    echo "  $0           # Run all tests"
    echo "  $0 quick     # Quick health check"
    echo "  $0 app-only  # Test Flask app only"
    exit 0
fi

# Handle script interruption
trap 'log_error "Testing interrupted"; exit 1' INT TERM

# Run main function
main "$@"