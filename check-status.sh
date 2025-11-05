#!/bin/bash
# 🔍 DevOps Pipeline Status Checker
# Shows the current status of all services and components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${PURPLE}🔍 $1${NC}"; }

# Status tracking
SERVICES_UP=0
SERVICES_DOWN=0
SERVICES_WARNING=0

# Helper function to check service status
check_service() {
    local service_name="$1"
    local check_command="$2"
    local status_type="${3:-binary}"  # binary, count, or custom
    
    printf "%-20s " "$service_name:"
    
    if [ "$status_type" = "binary" ]; then
        if eval "$check_command" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Running${NC}"
            ((SERVICES_UP++))
            return 0
        else
            echo -e "${RED}❌ Down${NC}"
            ((SERVICES_DOWN++))
            return 1
        fi
    elif [ "$status_type" = "count" ]; then
        local count=$(eval "$check_command" 2>/dev/null || echo "0")
        if [ "$count" -gt 0 ]; then
            echo -e "${GREEN}✅ Running ($count)${NC}"
            ((SERVICES_UP++))
            return 0
        else
            echo -e "${RED}❌ Down (0)${NC}"
            ((SERVICES_DOWN++))
            return 1
        fi
    fi
}

# Show system overview
show_system_overview() {
    log_header "System Overview"
    echo ""
    
    # System information
    echo "🖥️  System Information:"
    echo "   OS: $(uname -s) $(uname -r)"
    echo "   Hostname: $(hostname)"
    echo "   IP Address: $(hostname -I | awk '{print $1}' 2>/dev/null || echo 'Unknown')"
    echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo ""
    
    # Resource usage
    echo "💾 Resource Usage:"
    local memory_usage=$(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')
    local disk_usage=$(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    echo "   Memory: $memory_usage"
    echo "   Disk (/): $disk_usage"
    echo "   Load Average: $load_avg"
    echo ""
}

# Check core tools
check_core_tools() {
    log_header "Core Tools Status"
    echo ""
    
    check_service "Docker" "command -v docker && docker info"
    check_service "kubectl" "command -v kubectl"
    check_service "kind" "command -v kind"
    check_service "Helm" "command -v helm"
    check_service "Trivy" "command -v trivy"
    check_service "Jenkins" "systemctl is-active jenkins"
    
    echo ""
}

# Check Kubernetes cluster
check_kubernetes() {
    log_header "Kubernetes Cluster Status"
    echo ""
    
    # Check if cluster exists
    if ! kind get clusters 2>/dev/null | grep -q devops-cluster; then
        echo -e "Cluster:             ${RED}❌ Not Found${NC}"
        ((SERVICES_DOWN++))
        echo ""
        return 1
    fi
    
    echo -e "Cluster:             ${GREEN}✅ devops-cluster${NC}"
    ((SERVICES_UP++))
    
    # Check cluster connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "Connectivity:        ${GREEN}✅ Connected${NC}"
        ((SERVICES_UP++))
    else
        echo -e "Connectivity:        ${RED}❌ Failed${NC}"
        ((SERVICES_DOWN++))
        echo ""
        return 1
    fi
    
    # Check nodes
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || echo "0")
    
    if [ "$ready_nodes" -gt 0 ]; then
        echo -e "Nodes:               ${GREEN}✅ $ready_nodes/$node_count Ready${NC}"
        ((SERVICES_UP++))
    else
        echo -e "Nodes:               ${RED}❌ 0/$node_count Ready${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # Check namespaces
    local namespaces=("dev" "prod" "argocd" "monitoring")
    local ns_status=""
    local ns_count=0
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            ((ns_count++))
        fi
    done
    
    if [ "$ns_count" -eq 4 ]; then
        echo -e "Namespaces:          ${GREEN}✅ All Present ($ns_count/4)${NC}"
        ((SERVICES_UP++))
    else
        echo -e "Namespaces:          ${YELLOW}⚠️  Partial ($ns_count/4)${NC}"
        ((SERVICES_WARNING++))
    fi
    
    echo ""
}

# Check application deployments
check_applications() {
    log_header "Application Status"
    echo ""
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "Cannot check applications - cluster not accessible"
        echo ""
        return 1
    fi
    
    # Flask Application
    check_service "Flask App (dev)" "kubectl get deployment flask-app -n dev --no-headers | grep -q '1/1'"
    
    # Check Flask app pods
    local flask_pods=$(kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    printf "%-20s " "Flask Pods:"
    if [ "$flask_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ $flask_pods Running${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ 0 Running${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # ArgoCD
    check_service "ArgoCD Server" "kubectl get deployment argocd-server -n argocd --no-headers | grep -q '1/1'"
    
    # Monitoring Stack
    check_service "Prometheus" "kubectl get deployment prometheus-kube-prometheus-prometheus -n monitoring --no-headers"
    check_service "Grafana" "kubectl get deployment prometheus-grafana -n monitoring --no-headers | grep -q '1/1'"
    
    echo ""
}

# Check service endpoints
check_endpoints() {
    log_header "Service Endpoints"
    echo ""
    
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    # Jenkins
    printf "%-20s " "Jenkins (8080):"
    if curl -s --connect-timeout 5 "http://$server_ip:8080/login" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Accessible${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # ArgoCD
    printf "%-20s " "ArgoCD (30080):"
    if curl -s --connect-timeout 5 -k "http://$server_ip:30080" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Accessible${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # Prometheus
    printf "%-20s " "Prometheus (30090):"
    if curl -s --connect-timeout 5 "http://$server_ip:30090" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Accessible${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # Grafana
    printf "%-20s " "Grafana (30091):"
    if curl -s --connect-timeout 5 "http://$server_ip:30091" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Accessible${NC}"
        ((SERVICES_DOWN++))
    fi
    
    echo ""
}

# Test Flask application
test_flask_app() {
    log_header "Flask Application Tests"
    echo ""
    
    if ! kubectl get pods -n dev -l app=flask-app --field-selector=status.phase=Running --no-headers | grep -q flask-app; then
        echo -e "Flask app not running - skipping tests"
        echo ""
        return 1
    fi
    
    # Start port forward in background
    kubectl port-forward svc/flask-app-service 8080:80 -n dev >/dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Wait for port forward to establish
    sleep 3
    
    # Test endpoints
    printf "%-20s " "Health Endpoint:"
    if curl -s --connect-timeout 5 "http://localhost:8080/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Responding${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Responding${NC}"
        ((SERVICES_DOWN++))
    fi
    
    printf "%-20s " "API Endpoint:"
    if curl -s --connect-timeout 5 "http://localhost:8080/api/users" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Responding${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Responding${NC}"
        ((SERVICES_DOWN++))
    fi
    
    printf "%-20s " "Root Endpoint:"
    if curl -s --connect-timeout 5 "http://localhost:8080/" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Responding${NC}"
        ((SERVICES_UP++))
    else
        echo -e "${RED}❌ Not Responding${NC}"
        ((SERVICES_DOWN++))
    fi
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    echo ""
}

# Show detailed pod information
show_pod_details() {
    log_header "Pod Details"
    echo ""
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "Cannot show pod details - cluster not accessible"
        echo ""
        return 1
    fi
    
    echo "📦 Pods by Namespace:"
    echo ""
    
    local namespaces=("dev" "prod" "argocd" "monitoring")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            echo "🔹 Namespace: $ns"
            kubectl get pods -n "$ns" --no-headers 2>/dev/null | while read line; do
                if [ -n "$line" ]; then
                    local pod_name=$(echo "$line" | awk '{print $1}')
                    local ready=$(echo "$line" | awk '{print $2}')
                    local status=$(echo "$line" | awk '{print $3}')
                    local restarts=$(echo "$line" | awk '{print $4}')
                    
                    if [[ "$status" == "Running" ]]; then
                        echo -e "   ${GREEN}✅${NC} $pod_name ($ready) - $status (restarts: $restarts)"
                    elif [[ "$status" == "Pending" ]]; then
                        echo -e "   ${YELLOW}⏳${NC} $pod_name ($ready) - $status (restarts: $restarts)"
                    else
                        echo -e "   ${RED}❌${NC} $pod_name ($ready) - $status (restarts: $restarts)"
                    fi
                fi
            done
            echo ""
        fi
    done
}

# Show resource usage
show_resource_usage() {
    log_header "Resource Usage"
    echo ""
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "Cannot show resource usage - cluster not accessible"
        echo ""
        return 1
    fi
    
    echo "📊 Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo ""
    
    echo "📊 Pod Resource Usage (Top 10):"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -11 || echo "Metrics server not available"
    echo ""
}

# Show access information
show_access_info() {
    log_header "Access Information"
    echo ""
    
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "🌐 Service URLs:"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Service          │ URL                                      │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ 🔧 Jenkins       │ http://$server_ip:8080                   │"
    echo "│ 🔄 ArgoCD        │ http://$server_ip:30080                  │"
    echo "│ 📊 Prometheus    │ http://$server_ip:30090                  │"
    echo "│ 📈 Grafana       │ http://$server_ip:30091                  │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    echo "🔑 Credentials:"
    if [ -f "jenkins-credentials.txt" ]; then
        local jenkins_pass=$(cat jenkins-credentials.txt | grep "Password:" | cut -d' ' -f4 2>/dev/null || echo "Check file")
        echo "   Jenkins: admin / $jenkins_pass"
    else
        echo "   Jenkins: admin / (check jenkins-credentials.txt)"
    fi
    
    if [ -f "argocd-credentials.txt" ]; then
        local argocd_pass=$(cat argocd-credentials.txt | cut -d' ' -f4 2>/dev/null || echo "Check file")
        echo "   ArgoCD:  admin / $argocd_pass"
    else
        echo "   ArgoCD:  admin / (check argocd-credentials.txt)"
    fi
    
    echo "   Grafana: admin / admin123"
    echo ""
    
    echo "🚀 Flask Application:"
    echo "   Command: kubectl port-forward svc/flask-app-service 8080:80 -n dev"
    echo "   URL:     http://localhost:8080"
    echo ""
}

# Generate status summary
show_status_summary() {
    local total_services=$((SERVICES_UP + SERVICES_DOWN + SERVICES_WARNING))
    local health_percentage=0
    
    if [ $total_services -gt 0 ]; then
        health_percentage=$(( (SERVICES_UP * 100) / total_services ))
    fi
    
    echo "════════════════════════════════════════════════════════════════"
    log_header "Status Summary"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "📊 Overall Health: $health_percentage%"
    echo ""
    echo "Services Status:"
    echo -e "   ${GREEN}✅ Running: $SERVICES_UP${NC}"
    echo -e "   ${RED}❌ Down: $SERVICES_DOWN${NC}"
    echo -e "   ${YELLOW}⚠️  Warning: $SERVICES_WARNING${NC}"
    echo ""
    
    if [ $SERVICES_DOWN -eq 0 ] && [ $SERVICES_WARNING -eq 0 ]; then
        log_success "🎉 All systems operational!"
    elif [ $SERVICES_DOWN -eq 0 ]; then
        log_warning "⚠️  System mostly healthy with minor issues"
    else
        log_error "❌ System has issues that need attention"
        echo ""
        echo "🔧 Troubleshooting suggestions:"
        echo "1. Run: ./2-start-services.sh (restart services)"
        echo "2. Run: ./5-test-everything.sh (detailed testing)"
        echo "3. Check logs: kubectl logs -f deployment/<name> -n <namespace>"
        echo "4. Restart cluster: ./6-cleanup.sh cluster && ./2-start-services.sh"
    fi
    echo ""
}

# Handle different status modes
handle_status_mode() {
    local mode="$1"
    
    case "$mode" in
        "full"|"")
            show_system_overview
            check_core_tools
            check_kubernetes
            check_applications
            check_endpoints
            test_flask_app
            show_pod_details
            show_resource_usage
            show_access_info
            ;;
        "quick")
            check_core_tools
            check_kubernetes
            check_applications
            check_endpoints
            ;;
        "apps")
            check_applications
            test_flask_app
            show_pod_details
            ;;
        "cluster")
            check_kubernetes
            show_pod_details
            show_resource_usage
            ;;
        "endpoints")
            check_endpoints
            test_flask_app
            show_access_info
            ;;
        *)
            log_error "Unknown status mode: $mode"
            log_info "Available modes: full, quick, apps, cluster, endpoints"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    local mode="${1:-full}"
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║    🔍 DevOps Pipeline Status Check                           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    handle_status_mode "$mode"
    show_status_summary
}

# Show usage if help requested
if [[ "${1}" == "--help" || "${1}" == "-h" ]]; then
    echo "DevOps Pipeline Status Checker"
    echo ""
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Modes:"
    echo "  full       Complete status check (default)"
    echo "  quick      Quick health check of core services"
    echo "  apps       Application status only"
    echo "  cluster    Kubernetes cluster status only"
    echo "  endpoints  Service endpoints and connectivity"
    echo ""
    echo "Examples:"
    echo "  $0           # Full status check"
    echo "  $0 quick     # Quick health check"
    echo "  $0 apps      # Application status"
    echo "  $0 cluster   # Cluster status"
    exit 0
fi

# Run main function
main "$@"