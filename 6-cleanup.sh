#!/bin/bash
# 🧹 Complete System Cleanup Script
# Removes all DevOps pipeline components and resources

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

log_info "🧹 DevOps Pipeline Cleanup Script"
echo ""

# Show what will be cleaned up
show_cleanup_plan() {
    log_warning "⚠️  This script will remove:"
    echo "  🎯 Kind Kubernetes cluster (devops-cluster)"
    echo "  🐳 Docker images (devops-flask-app, downloaded images)"
    echo "  🔧 Jenkins data and jobs"
    echo "  📊 Monitoring data (Prometheus, Grafana)"
    echo "  📁 Generated credential files"
    echo "  🗂️  Temporary files and logs"
    echo ""
    log_warning "⚠️  This will NOT remove:"
    echo "  ✅ Installed software (Docker, kubectl, Jenkins, etc.)"
    echo "  ✅ Source code and configuration files"
    echo "  ✅ System packages and dependencies"
    echo ""
}

# Confirm cleanup
confirm_cleanup() {
    local mode="$1"
    
    if [[ "$mode" != "force" ]]; then
        show_cleanup_plan
        read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
}

# Stop and remove Kind cluster
cleanup_kubernetes() {
    log_info "☸️  Cleaning up Kubernetes cluster..."
    
    if kind get clusters 2>/dev/null | grep -q devops-cluster; then
        log_info "Deleting kind cluster: devops-cluster"
        kind delete cluster --name devops-cluster
        log_success "Kubernetes cluster removed"
    else
        log_info "No kind cluster found to remove"
    fi
    
    # Clean up kubectl contexts
    kubectl config delete-context kind-devops-cluster 2>/dev/null || true
    kubectl config delete-cluster kind-devops-cluster 2>/dev/null || true
}

# Clean up Docker resources
cleanup_docker() {
    log_info "🐳 Cleaning up Docker resources..."
    
    # Stop any running containers
    log_info "Stopping running containers..."
    docker ps -q | xargs -r docker stop 2>/dev/null || true
    
    # Remove application images
    log_info "Removing application Docker images..."
    docker rmi devops-flask-app:latest 2>/dev/null || true
    
    # Remove dangling images
    log_info "Removing dangling images..."
    docker image prune -f >/dev/null 2>&1 || true
    
    # Clean up volumes (optional)
    read -p "Remove Docker volumes? This will delete all container data (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f >/dev/null 2>&1 || true
        log_success "Docker volumes cleaned"
    fi
    
    # Clean up networks
    docker network prune -f >/dev/null 2>&1 || true
    
    log_success "Docker resources cleaned"
}

# Clean up Jenkins
cleanup_jenkins() {
    log_info "🔧 Cleaning up Jenkins..."
    
    if systemctl is-active --quiet jenkins 2>/dev/null; then
        log_info "Stopping Jenkins service..."
        sudo systemctl stop jenkins
    fi
    
    # Clean Jenkins workspace and jobs
    if [ -d "/var/lib/jenkins/workspace" ]; then
        log_info "Cleaning Jenkins workspace..."
        sudo rm -rf /var/lib/jenkins/workspace/* 2>/dev/null || true
    fi
    
    if [ -d "/var/lib/jenkins/jobs" ]; then
        log_info "Removing Jenkins jobs..."
        sudo rm -rf /var/lib/jenkins/jobs/devops-* 2>/dev/null || true
    fi
    
    # Restart Jenkins to clean state
    if command -v systemctl >/dev/null 2>&1; then
        log_info "Restarting Jenkins..."
        sudo systemctl start jenkins
        log_success "Jenkins cleaned and restarted"
    else
        log_warning "Could not restart Jenkins automatically"
    fi
}

# Clean up generated files
cleanup_files() {
    log_info "📁 Cleaning up generated files..."
    
    # Remove credential files
    rm -f jenkins-credentials.txt
    rm -f argocd-credentials.txt
    rm -f devops-credentials.txt
    
    # Remove temporary files
    rm -f kind-config.yaml
    rm -f pipeline-config.xml
    rm -f docker-config.xml
    rm -f security-report.txt
    rm -f test-report.txt
    
    # Remove log files
    rm -f *.log
    rm -f nohup.out
    
    log_success "Generated files cleaned"
}

# Clean up Helm releases
cleanup_helm() {
    log_info "⚓ Cleaning up Helm releases..."
    
    # List and remove Helm releases
    if command -v helm >/dev/null 2>&1; then
        # Remove monitoring stack
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        
        # Remove any other releases
        helm list --all-namespaces --short | xargs -r helm uninstall 2>/dev/null || true
        
        log_success "Helm releases cleaned"
    else
        log_info "Helm not installed, skipping Helm cleanup"
    fi
}

# Clean up system resources
cleanup_system() {
    log_info "🗑️  Cleaning up system resources..."
    
    # Clean package cache (if applicable)
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get autoremove -y >/dev/null 2>&1 || true
        sudo apt-get autoclean >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf autoremove -y >/dev/null 2>&1 || true
        sudo dnf clean all >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        sudo yum autoremove -y >/dev/null 2>&1 || true
        sudo yum clean all >/dev/null 2>&1 || true
    fi
    
    # Clean temporary directories
    sudo rm -rf /tmp/kind-* 2>/dev/null || true
    sudo rm -rf /tmp/helm-* 2>/dev/null || true
    
    log_success "System resources cleaned"
}

# Verify cleanup
verify_cleanup() {
    log_info "🔍 Verifying cleanup..."
    
    local issues=()
    
    # Check if cluster still exists
    if kind get clusters 2>/dev/null | grep -q devops-cluster; then
        issues+=("Kind cluster still exists")
    fi
    
    # Check for application images
    if docker images devops-flask-app:latest --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q devops-flask-app; then
        issues+=("Application Docker image still exists")
    fi
    
    # Check for credential files
    if [ -f jenkins-credentials.txt ] || [ -f argocd-credentials.txt ]; then
        issues+=("Credential files still exist")
    fi
    
    if [ ${#issues[@]} -eq 0 ]; then
        log_success "Cleanup verification passed"
    else
        log_warning "Cleanup verification found issues:"
        for issue in "${issues[@]}"; do
            echo "  ⚠️  $issue"
        done
    fi
}

# Show post-cleanup information
show_post_cleanup_info() {
    log_success "🎉 Cleanup completed successfully!"
    echo ""
    log_info "📋 What was cleaned:"
    echo "  ✅ Kubernetes cluster and resources"
    echo "  ✅ Docker images and containers"
    echo "  ✅ Jenkins jobs and workspace"
    echo "  ✅ Generated credential files"
    echo "  ✅ Temporary files and logs"
    echo ""
    log_info "💾 What remains installed:"
    echo "  ✅ Docker Engine"
    echo "  ✅ kubectl"
    echo "  ✅ kind"
    echo "  ✅ Helm"
    echo "  ✅ Jenkins"
    echo "  ✅ Trivy"
    echo "  ✅ Source code and configurations"
    echo ""
    log_info "🚀 To restart the pipeline:"
    echo "  1. ./2-start-services.sh    # Recreate cluster and services"
    echo "  2. ./3-create-pipeline.sh   # Recreate Jenkins pipeline"
    echo "  3. ./4-deploy-flask.sh      # Deploy application"
    echo ""
    log_info "🗑️  To completely remove all software:"
    echo "  Run: $0 --uninstall"
}

# Complete uninstall (remove all software)
complete_uninstall() {
    log_warning "🚨 COMPLETE UNINSTALL MODE"
    log_warning "This will remove ALL installed DevOps software!"
    echo ""
    read -p "Are you absolutely sure? Type 'UNINSTALL' to confirm: " confirm
    
    if [ "$confirm" != "UNINSTALL" ]; then
        log_info "Uninstall cancelled"
        exit 0
    fi
    
    log_info "🗑️  Removing all DevOps software..."
    
    # Stop services
    sudo systemctl stop jenkins 2>/dev/null || true
    sudo systemctl stop docker 2>/dev/null || true
    
    # Remove packages
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get remove -y jenkins docker-ce docker-ce-cli containerd.io 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf remove -y jenkins docker-ce docker-ce-cli containerd.io 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        sudo yum remove -y jenkins docker-ce docker-ce-cli containerd.io 2>/dev/null || true
    fi
    
    # Remove binaries
    sudo rm -f /usr/local/bin/kubectl
    sudo rm -f /usr/local/bin/kind
    sudo rm -f /usr/local/bin/helm
    sudo rm -f /usr/local/bin/trivy
    
    # Remove data directories
    sudo rm -rf /var/lib/jenkins
    sudo rm -rf /var/lib/docker
    sudo rm -rf ~/.kube
    sudo rm -rf ~/.docker
    
    log_success "Complete uninstall finished"
}

# Handle different cleanup modes
handle_cleanup_mode() {
    local mode="$1"
    
    case "$mode" in
        "all"|"")
            log_info "🧹 Full cleanup mode"
            cleanup_kubernetes
            cleanup_docker
            cleanup_jenkins
            cleanup_helm
            cleanup_files
            cleanup_system
            verify_cleanup
            ;;
        "cluster")
            log_info "☸️  Cluster-only cleanup"
            cleanup_kubernetes
            cleanup_files
            ;;
        "docker")
            log_info "🐳 Docker-only cleanup"
            cleanup_docker
            ;;
        "jenkins")
            log_info "🔧 Jenkins-only cleanup"
            cleanup_jenkins
            ;;
        "files")
            log_info "📁 Files-only cleanup"
            cleanup_files
            ;;
        "--uninstall")
            complete_uninstall
            return 0
            ;;
        *)
            log_error "Unknown cleanup mode: $mode"
            log_info "Available modes: all, cluster, docker, jenkins, files"
            log_info "Special mode: --uninstall (removes all software)"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    local mode="${1:-all}"
    local force_flag="$2"
    
    if [[ "$mode" == "--uninstall" ]]; then
        complete_uninstall
        return 0
    fi
    
    confirm_cleanup "$force_flag"
    handle_cleanup_mode "$mode"
    
    if [[ "$mode" == "all" || "$mode" == "" ]]; then
        show_post_cleanup_info
    else
        log_success "Cleanup mode '$mode' completed"
    fi
}

# Show usage if help requested
if [[ "${1}" == "--help" || "${1}" == "-h" ]]; then
    echo "DevOps Pipeline Cleanup Script"
    echo ""
    echo "Usage: $0 [MODE] [--force]"
    echo ""
    echo "Modes:"
    echo "  all        Complete cleanup (default)"
    echo "  cluster    Remove Kubernetes cluster only"
    echo "  docker     Clean Docker resources only"
    echo "  jenkins    Clean Jenkins data only"
    echo "  files      Remove generated files only"
    echo "  --uninstall Remove all installed software"
    echo ""
    echo "Options:"
    echo "  --force    Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full cleanup with confirmation"
    echo "  $0 all --force        # Full cleanup without confirmation"
    echo "  $0 cluster            # Remove cluster only"
    echo "  $0 docker             # Clean Docker only"
    echo "  $0 --uninstall        # Remove all software"
    exit 0
fi

# Handle script interruption
trap 'log_error "Cleanup interrupted"; exit 1' INT TERM

# Run main function
main "$@"