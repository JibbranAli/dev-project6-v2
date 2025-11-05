#!/bin/bash
# 🚀 DevOps Pipeline Complete Installer
# Auto-detects Linux distribution and installs all required software
# Compatible with: Ubuntu, RHEL, CentOS, Fedora, Debian, SUSE

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "🚀 Starting DevOps Pipeline Installation..."
log_info "This will install: Docker, Kubernetes, Jenkins, Security Tools, and Monitoring"

# Detect Linux distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected OS: $OS $VER"
}

# Install packages based on distribution
install_packages() {
    local packages="$1"
    
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y $packages
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora/RHEL 8+
        dnf install -y $packages
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL 7
        yum install -y $packages
    elif command -v zypper >/dev/null 2>&1; then
        # SUSE/openSUSE
        zypper install -y $packages
    else
        log_error "No supported package manager found"
        exit 1
    fi
}

# Install Docker
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker already installed"
        return
    fi
    
    log_info "📦 Installing Docker..."
    
    # Install prerequisites
    install_packages "curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release"
    
    # Install Docker using official script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group if not root
    if [ "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        log_info "Added $SUDO_USER to docker group (logout/login required)"
    fi
    
    log_success "Docker installed successfully"
}

# Install Java (required for Jenkins)
install_java() {
    if command -v java >/dev/null 2>&1; then
        log_success "Java already installed"
        return
    fi
    
    log_info "📦 Installing Java..."
    
    if command -v apt-get >/dev/null 2>&1; then
        install_packages "openjdk-17-jdk"
    elif command -v dnf >/dev/null 2>&1; then
        install_packages "java-17-openjdk java-17-openjdk-devel"
    elif command -v yum >/dev/null 2>&1; then
        install_packages "java-17-openjdk java-17-openjdk-devel"
    elif command -v zypper >/dev/null 2>&1; then
        install_packages "java-17-openjdk java-17-openjdk-devel"
    fi
    
    log_success "Java installed successfully"
}

# Install Jenkins
install_jenkins() {
    if command -v jenkins >/dev/null 2>&1 || systemctl is-active --quiet jenkins; then
        log_success "Jenkins already installed"
        return
    fi
    
    log_info "📦 Installing Jenkins..."
    
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
        echo "deb https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
        apt-get update
        apt-get install -y jenkins
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora/RHEL 8+
        wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
        dnf install -y jenkins
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL 7
        wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
        yum install -y jenkins
    elif command -v zypper >/dev/null 2>&1; then
        # SUSE
        zypper addrepo -f http://pkg.jenkins.io/opensuse-stable/ jenkins
        zypper install -y jenkins
    fi
    
    # Start and enable Jenkins
    systemctl start jenkins
    systemctl enable jenkins
    
    # Wait for Jenkins to start
    log_info "Waiting for Jenkins to start..."
    sleep 30
    
    # Get initial admin password
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
        echo "Jenkins Admin Password: $JENKINS_PASSWORD" > jenkins-credentials.txt
        log_success "Jenkins installed! Admin password saved to jenkins-credentials.txt"
        log_warning "IMPORTANT: Save this password: $JENKINS_PASSWORD"
    else
        log_warning "Jenkins password file not found. Check /var/lib/jenkins/secrets/"
    fi
}

# Install kubectl
install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        log_success "kubectl already installed"
        return
    fi
    
    log_info "📦 Installing kubectl..."
    
    # Get latest stable version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Install kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl installed successfully"
}

# Install kind (Kubernetes in Docker)
install_kind() {
    if command -v kind >/dev/null 2>&1; then
        log_success "kind already installed"
        return
    fi
    
    log_info "📦 Installing kind..."
    
    # Download and install kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    
    log_success "kind installed successfully"
}

# Install Helm
install_helm() {
    if command -v helm >/dev/null 2>&1; then
        log_success "Helm already installed"
        return
    fi
    
    log_info "📦 Installing Helm..."
    
    # Install Helm using official script
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm installed successfully"
}

# Install Trivy (Security Scanner)
install_trivy() {
    if command -v trivy >/dev/null 2>&1; then
        log_success "Trivy already installed"
        return
    fi
    
    log_info "📦 Installing Trivy..."
    
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
        apt-get update
        apt-get install -y trivy
    else
        # Universal installation
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi
    
    log_success "Trivy installed successfully"
}

# Configure firewall
configure_firewall() {
    log_info "🔧 Configuring firewall..."
    
    # Open required ports
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 8080/tcp   # Jenkins
        ufw allow 30080/tcp  # ArgoCD
        ufw allow 30090/tcp  # Prometheus
        ufw allow 30091/tcp  # Grafana
        log_success "UFW firewall configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=8080/tcp   # Jenkins
        firewall-cmd --permanent --add-port=30080/tcp  # ArgoCD
        firewall-cmd --permanent --add-port=30090/tcp  # Prometheus
        firewall-cmd --permanent --add-port=30091/tcp  # Grafana
        firewall-cmd --reload
        log_success "firewalld configured"
    else
        log_warning "No firewall detected. You may need to open ports manually"
    fi
}

# Pre-pull required Docker images
pull_docker_images() {
    log_info "📥 Pre-pulling required Docker images..."
    
    # List of images to pre-pull
    images=(
        "jenkins/jenkins:lts"
        "postgres:13"
        "redis:7-alpine"
        "nginx:alpine"
        "python:3.9-slim"
        "quay.io/argoproj/argocd:latest"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
    )
    
    for image in "${images[@]}"; do
        log_info "Pulling $image..."
        docker pull "$image" || log_warning "Failed to pull $image"
    done
    
    log_success "Docker images pre-pulled"
}

# Main installation function
main() {
    log_info "🔍 Detecting system configuration..."
    detect_os
    
    log_info "📋 Installation will include:"
    echo "   • Docker (Container Runtime)"
    echo "   • Java 17 (Jenkins Requirement)"  
    echo "   • Jenkins (CI/CD Server)"
    echo "   • kubectl (Kubernetes CLI)"
    echo "   • kind (Local Kubernetes)"
    echo "   • Helm (Package Manager)"
    echo "   • Trivy (Security Scanner)"
    echo "   • Required Docker Images"
    echo ""
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Install components
    install_docker
    install_java
    install_jenkins
    install_kubectl
    install_kind
    install_helm
    install_trivy
    configure_firewall
    pull_docker_images
    
    # Final setup
    log_info "🔧 Final configuration..."
    
    # Create credentials file
    cat > devops-credentials.txt << EOF
=== DevOps Pipeline Credentials ===

Jenkins:
- URL: http://$(hostname -I | awk '{print $1}'):8080
- Username: admin
- Password: $(cat jenkins-credentials.txt 2>/dev/null | cut -d' ' -f4 || echo "Check /var/lib/jenkins/secrets/initialAdminPassword")

Next Steps:
1. Run: ./2-start-services.sh
2. Run: ./3-create-pipeline.sh
3. Access services using URLs above

EOF
    
    log_success "🎉 Installation completed successfully!"
    echo ""
    log_info "📋 What was installed:"
    echo "   ✅ Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "   ✅ Java $(java -version 2>&1 | head -n1 | cut -d'"' -f2)"
    echo "   ✅ Jenkins (running on port 8080)"
    echo "   ✅ kubectl $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    echo "   ✅ kind $(kind version | cut -d' ' -f2)"
    echo "   ✅ Helm $(helm version --short | cut -d' ' -f1)"
    echo "   ✅ Trivy $(trivy --version | head -n1 | cut -d' ' -f2)"
    echo ""
    log_info "📝 Credentials saved to: devops-credentials.txt"
    echo ""
    log_warning "🚨 IMPORTANT JENKINS SETUP:"
    echo "1. Open: http://$(hostname -I | awk '{print $1}'):8080"
    echo "2. Use admin password from jenkins-credentials.txt"
    echo "3. Install suggested plugins"
    echo "4. Create admin user"
    echo ""
    log_info "Next steps:"
    echo "1. ./2-start-services.sh    # Start Kubernetes cluster and services"
    echo "2. ./3-create-pipeline.sh   # Create Jenkins pipeline"
}