#!/bin/bash
# 🚀 One-Command DevOps Pipeline Setup
# Perfect for beginners - sets up everything automatically

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
log_step() { echo -e "${PURPLE}🎯 $1${NC}"; }
log_highlight() { echo -e "${CYAN}🌟 $1${NC}"; }

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 DevOps Pipeline Quick Start                            ║
║                                                              ║
║    Complete CI/CD Pipeline in One Command!                  ║
║    Perfect for Learning DevOps Concepts                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Show what will be installed
show_installation_plan() {
    log_highlight "🎯 What This Script Will Do:"
    echo ""
    echo "📦 INSTALL SOFTWARE:"
    echo "   • Docker (Container Platform)"
    echo "   • Kubernetes Tools (kubectl, kind)"
    echo "   • Jenkins (CI/CD Server)"
    echo "   • Helm (Package Manager)"
    echo "   • Trivy (Security Scanner)"
    echo ""
    echo "🏗️  CREATE INFRASTRUCTURE:"
    echo "   • Local Kubernetes Cluster"
    echo "   • Development & Production Namespaces"
    echo "   • ArgoCD (GitOps Platform)"
    echo "   • Prometheus & Grafana (Monitoring)"
    echo ""
    echo "🚀 DEPLOY APPLICATION:"
    echo "   • Flask Web Application"
    echo "   • PostgreSQL Database"
    echo "   • Redis Cache"
    echo "   • Complete CI/CD Pipeline"
    echo ""
    echo "⏱️  ESTIMATED TIME: 10-15 minutes"
    echo "💾 DISK SPACE NEEDED: ~5GB"
    echo "🧠 MEMORY NEEDED: ~4GB RAM"
    echo ""
}

# Check system requirements
check_requirements() {
    log_step "🔍 Checking System Requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Please run this script as a regular user (not root)"
        log_info "The script will ask for sudo password when needed"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script needs sudo access to install software"
        sudo -v || {
            log_error "Sudo access required. Please run: sudo -v"
            exit 1
        }
    fi
    
    # Check disk space (need at least 5GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 5000000 ]; then
        log_error "Insufficient disk space. Need at least 5GB free"
        log_info "Available: $(( available_space / 1000000 ))GB"
        exit 1
    fi
    
    # Check memory (need at least 2GB)
    local available_memory=$(free -m | grep '^Mem:' | awk '{print $2}')
    if [ "$available_memory" -lt 2000 ]; then
        log_error "Insufficient memory. Need at least 2GB RAM"
        log_info "Available: ${available_memory}MB"
        exit 1
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 https://google.com >/dev/null; then
        log_error "No internet connection. Please check your network"
        exit 1
    fi
    
    log_success "System requirements check passed"
}

# Progress tracking
TOTAL_STEPS=6
CURRENT_STEP=0

show_progress() {
    ((CURRENT_STEP++))
    local percentage=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))
    echo ""
    log_highlight "📊 Progress: Step $CURRENT_STEP/$TOTAL_STEPS ($percentage%)"
    echo ""
}

# Step 1: Install all software
install_software() {
    show_progress
    log_step "📦 Step 1: Installing DevOps Software..."
    
    if [ ! -f "1-install-all.sh" ]; then
        log_error "Installation script not found: 1-install-all.sh"
        exit 1
    fi
    
    chmod +x 1-install-all.sh
    sudo ./1-install-all.sh
    
    log_success "All software installed successfully"
}

# Step 2: Start services
start_services() {
    show_progress
    log_step "🏗️  Step 2: Starting Kubernetes Cluster & Services..."
    
    if [ ! -f "2-start-services.sh" ]; then
        log_error "Services script not found: 2-start-services.sh"
        exit 1
    fi
    
    chmod +x 2-start-services.sh
    ./2-start-services.sh
    
    log_success "All services started successfully"
}

# Step 3: Create Jenkins pipeline
create_pipeline() {
    show_progress
    log_step "🔧 Step 3: Creating Jenkins CI/CD Pipeline..."
    
    if [ ! -f "3-create-pipeline.sh" ]; then
        log_error "Pipeline script not found: 3-create-pipeline.sh"
        exit 1
    fi
    
    chmod +x 3-create-pipeline.sh
    ./3-create-pipeline.sh
    
    log_success "Jenkins pipeline created successfully"
}

# Step 4: Deploy Flask application
deploy_application() {
    show_progress
    log_step "🚀 Step 4: Deploying Flask Application..."
    
    if [ ! -f "4-deploy-flask.sh" ]; then
        log_error "Deployment script not found: 4-deploy-flask.sh"
        exit 1
    fi
    
    chmod +x 4-deploy-flask.sh
    ./4-deploy-flask.sh
    
    log_success "Flask application deployed successfully"
}

# Step 5: Run tests
run_tests() {
    show_progress
    log_step "🧪 Step 5: Running System Tests..."
    
    if [ ! -f "5-test-everything.sh" ]; then
        log_error "Test script not found: 5-test-everything.sh"
        exit 1
    fi
    
    chmod +x 5-test-everything.sh
    ./5-test-everything.sh quick
    
    log_success "System tests completed"
}

# Step 6: Show final information
show_completion() {
    show_progress
    log_step "🎉 Step 6: Setup Complete!"
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║  🎉 CONGRATULATIONS! Your DevOps Pipeline is Ready!         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_highlight "🌐 Access Your Services:"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Service          │ URL                                      │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ 🔧 Jenkins       │ http://$server_ip:8080                   │"
    echo "│ 🔄 ArgoCD        │ http://$server_ip:30080                  │"
    echo "│ 📊 Prometheus    │ http://$server_ip:30090                  │"
    echo "│ 📈 Grafana       │ http://$server_ip:30091                  │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_highlight "🔑 Login Credentials:"
    echo ""
    if [ -f "jenkins-credentials.txt" ]; then
        local jenkins_pass=$(cat jenkins-credentials.txt | grep "Password:" | cut -d' ' -f4 2>/dev/null || echo "Check jenkins-credentials.txt")
        echo "🔧 Jenkins:    admin / $jenkins_pass"
    else
        echo "🔧 Jenkins:    admin / (check jenkins-credentials.txt)"
    fi
    
    if [ -f "argocd-credentials.txt" ]; then
        local argocd_pass=$(cat argocd-credentials.txt | cut -d' ' -f4 2>/dev/null || echo "Check argocd-credentials.txt")
        echo "🔄 ArgoCD:     admin / $argocd_pass"
    else
        echo "🔄 ArgoCD:     admin / (check argocd-credentials.txt)"
    fi
    
    echo "📈 Grafana:    admin / admin123"
    echo ""
    
    log_highlight "🚀 Access Your Flask Application:"
    echo ""
    echo "Run this command in a new terminal:"
    echo "kubectl port-forward svc/flask-app-service 8080:80 -n dev"
    echo ""
    echo "Then visit: http://localhost:8080"
    echo ""
    
    log_highlight "📚 What You Can Do Now:"
    echo ""
    echo "1. 🎮 EXPLORE JENKINS:"
    echo "   • Open http://$server_ip:8080"
    echo "   • Click on 'devops-flask-pipeline'"
    echo "   • Click 'Build Now' to run the pipeline"
    echo ""
    echo "2. 🔍 MONITOR YOUR APP:"
    echo "   • Grafana: http://$server_ip:30091"
    echo "   • Prometheus: http://$server_ip:30090"
    echo ""
    echo "3. 🛠️  MODIFY THE CODE:"
    echo "   • Edit files in app/ folder"
    echo "   • Run: ./4-deploy-flask.sh"
    echo "   • Watch Jenkins automatically deploy changes"
    echo ""
    echo "4. 🧪 RUN TESTS:"
    echo "   • Full tests: ./5-test-everything.sh"
    echo "   • Quick check: ./5-test-everything.sh quick"
    echo ""
    echo "5. 🧹 CLEAN UP (when done):"
    echo "   • Remove everything: ./6-cleanup.sh"
    echo "   • Remove software too: ./6-cleanup.sh --uninstall"
    echo ""
    
    log_highlight "🎓 Learning Resources:"
    echo ""
    echo "• 📖 Read README.md for detailed explanations"
    echo "• 🔍 Check docs/ folder for architecture details"
    echo "• 🧪 Experiment with different configurations"
    echo "• 🚀 Try deploying your own applications"
    echo ""
    
    log_success "🎉 Happy Learning! Your DevOps journey starts now!"
}

# Handle errors gracefully
handle_error() {
    local exit_code=$?
    log_error "Setup failed at step $CURRENT_STEP"
    echo ""
    log_info "🔧 Troubleshooting:"
    echo "1. Check the error messages above"
    echo "2. Ensure you have sudo privileges"
    echo "3. Check internet connectivity"
    echo "4. Try running individual scripts manually"
    echo "5. Run: ./6-cleanup.sh && ./quick-start.sh"
    echo ""
    log_info "📞 Need help? Check the troubleshooting section in README.md"
    exit $exit_code
}

# Main execution
main() {
    # Set up error handling
    trap 'handle_error' ERR
    
    show_banner
    show_installation_plan
    
    # Confirm before starting
    read -p "Ready to start? This will take 10-15 minutes (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled. Run this script again when ready!"
        exit 0
    fi
    
    echo ""
    log_highlight "🚀 Starting DevOps Pipeline Setup..."
    
    # Check system first
    check_requirements
    
    # Run all setup steps
    install_software
    start_services
    create_pipeline
    deploy_application
    run_tests
    show_completion
}

# Show usage if help requested
if [[ "${1}" == "--help" || "${1}" == "-h" ]]; then
    show_banner
    echo "DevOps Pipeline Quick Start Script"
    echo ""
    echo "This script automatically sets up a complete DevOps pipeline including:"
    echo "• Docker, Kubernetes, Jenkins, and monitoring tools"
    echo "• Local Kubernetes cluster with sample Flask application"
    echo "• Complete CI/CD pipeline with security scanning"
    echo "• Monitoring dashboards and GitOps deployment"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Requirements:"
    echo "• Linux system (Ubuntu, RHEL, CentOS, Fedora, Debian, SUSE)"
    echo "• Sudo privileges"
    echo "• 5GB free disk space"
    echo "• 4GB RAM"
    echo "• Internet connection"
    echo ""
    echo "Time: 10-15 minutes"
    echo ""
    echo "After completion, access Jenkins at http://YOUR_IP:8080"
    exit 0
fi

# Handle script interruption
trap 'log_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"