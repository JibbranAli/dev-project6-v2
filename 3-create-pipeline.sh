#!/bin/bash
# 🚀 Jenkins Pipeline Creator
# Automatically creates and configures Jenkins pipeline

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

log_info "🚀 Creating Jenkins Pipeline..."

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
JENKINS_URL="http://${SERVER_IP}:8080"

# Check if Jenkins is running
check_jenkins() {
    log_info "🔍 Checking Jenkins status..."
    
    if ! curl -s "$JENKINS_URL/login" >/dev/null 2>&1; then
        log_error "Jenkins is not accessible at $JENKINS_URL"
        log_info "Please ensure Jenkins is running and accessible"
        log_info "Run: sudo systemctl status jenkins"
        exit 1
    fi
    
    log_success "Jenkins is accessible"
}

# Get Jenkins credentials
get_jenkins_credentials() {
    log_info "🔑 Getting Jenkins credentials..."
    
    if [ -f jenkins-credentials.txt ]; then
        JENKINS_PASSWORD=$(cat jenkins-credentials.txt | grep "Password:" | cut -d' ' -f4 2>/dev/null || echo "")
    fi
    
    if [ -z "$JENKINS_PASSWORD" ]; then
        # Try to get from default location
        if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
            JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$JENKINS_PASSWORD" ]; then
        log_warning "Could not find Jenkins password automatically"
        echo ""
        log_info "Please find your Jenkins admin password:"
        echo "1. Check jenkins-credentials.txt file"
        echo "2. Or run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
        echo ""
        read -p "Enter Jenkins admin password: " -s JENKINS_PASSWORD
        echo ""
    fi
    
    log_success "Jenkins credentials obtained"
}

# Wait for Jenkins to be fully ready
wait_for_jenkins() {
    log_info "⏳ Waiting for Jenkins to be fully ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -u "admin:$JENKINS_PASSWORD" "$JENKINS_URL/api/json" >/dev/null 2>&1; then
            log_success "Jenkins is ready"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - Jenkins not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Jenkins did not become ready within expected time"
    return 1
}

# Install required Jenkins plugins
install_jenkins_plugins() {
    log_info "🔌 Installing required Jenkins plugins..."
    
    # List of required plugins
    local plugins=(
        "workflow-aggregator"
        "docker-workflow"
        "kubernetes"
        "git"
        "github"
        "pipeline-stage-view"
        "blueocean"
        "build-timeout"
        "timestamper"
        "ws-cleanup"
    )
    
    for plugin in "${plugins[@]}"; do
        log_info "Installing plugin: $plugin"
        curl -s -X POST -u "admin:$JENKINS_PASSWORD" \
            "$JENKINS_URL/pluginManager/installNecessaryPlugins" \
            -d "<jenkins><install plugin='$plugin@latest' /></jenkins>" \
            -H "Content-Type: text/xml" >/dev/null 2>&1 || true
    done
    
    log_info "Restarting Jenkins to activate plugins..."
    curl -s -X POST -u "admin:$JENKINS_PASSWORD" "$JENKINS_URL/safeRestart" >/dev/null 2>&1 || true
    
    # Wait for restart
    sleep 30
    wait_for_jenkins
    
    log_success "Jenkins plugins installed"
}

# Create Jenkins pipeline job
create_pipeline_job() {
    log_info "📋 Creating Jenkins pipeline job..."
    
    # Get current directory for Git repository
    local git_repo_path=$(pwd)
    
    # Create job configuration XML
    cat > pipeline-config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>DevOps Flask Application Pipeline - Automated CI/CD</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
          <ignorePostCommitHooks>false</ignorePostCommitHooks>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.8.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>file://${git_repo_path}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>jenkins/Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
    
    # Create the job
    curl -s -X POST -u "admin:$JENKINS_PASSWORD" \
        "$JENKINS_URL/createItem?name=devops-flask-pipeline" \
        -H "Content-Type: application/xml" \
        --data-binary @pipeline-config.xml >/dev/null 2>&1
    
    rm pipeline-config.xml
    
    log_success "Pipeline job created: devops-flask-pipeline"
}

# Configure Jenkins system settings
configure_jenkins_system() {
    log_info "⚙️  Configuring Jenkins system settings..."
    
    # Configure Docker
    cat > docker-config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.docker.commons.tools.DockerTool_-DescriptorImpl plugin="docker-commons@1.17">
  <installations>
    <org.jenkinsci.plugins.docker.commons.tools.DockerTool>
      <name>docker</name>
      <home>/usr/bin/docker</home>
      <properties/>
    </org.jenkinsci.plugins.docker.commons.tools.DockerTool>
  </installations>
</org.jenkinsci.plugins.docker.commons.tools.DockerTool_-DescriptorImpl>
EOF
    
    curl -s -X POST -u "admin:$JENKINS_PASSWORD" \
        "$JENKINS_URL/configSubmit" \
        -H "Content-Type: application/xml" \
        --data-binary @docker-config.xml >/dev/null 2>&1 || true
    
    rm docker-config.xml
    
    log_success "Jenkins system configured"
}

# Run initial pipeline build
run_initial_build() {
    log_info "🚀 Running initial pipeline build..."
    
    # Trigger build
    curl -s -X POST -u "admin:$JENKINS_PASSWORD" \
        "$JENKINS_URL/job/devops-flask-pipeline/build" >/dev/null 2>&1
    
    log_success "Initial build triggered"
    log_info "Monitor build progress at: $JENKINS_URL/job/devops-flask-pipeline/"
}

# Display setup completion info
show_completion_info() {
    log_success "🎉 Jenkins Pipeline Setup Complete!"
    echo ""
    log_info "🌐 Access Information:"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Jenkins Dashboard: $JENKINS_URL                    │"
    echo "│ Pipeline Job:      $JENKINS_URL/job/devops-flask-pipeline/ │"
    echo "│ Username:          admin                                    │"
    echo "│ Password:          (check jenkins-credentials.txt)          │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    log_info "📋 What the Pipeline Does:"
    echo "1. 🧪 Runs unit tests on your code"
    echo "2. 🐳 Builds Docker container image"
    echo "3. 🛡️  Scans for security vulnerabilities"
    echo "4. 🚀 Deploys to Kubernetes cluster"
    echo "5. ✅ Verifies deployment success"
    echo ""
    log_info "🎯 Next Steps:"
    echo "1. Open Jenkins: $JENKINS_URL"
    echo "2. Login with admin credentials"
    echo "3. Click on 'devops-flask-pipeline' job"
    echo "4. Click 'Build Now' to run the pipeline"
    echo "5. Watch the pipeline execute!"
    echo ""
    log_info "🔄 Automatic Triggers:"
    echo "• Pipeline runs automatically when you push code changes"
    echo "• Checks for changes every 5 minutes"
    echo "• Manual builds available anytime"
    echo ""
    log_warning "📝 Important Notes:"
    echo "• First build may take longer (downloading dependencies)"
    echo "• Check build logs if pipeline fails"
    echo "• Pipeline deploys to 'dev' namespace by default"
}

# Main execution
main() {
    check_jenkins
    get_jenkins_credentials
    wait_for_jenkins
    install_jenkins_plugins
    configure_jenkins_system
    create_pipeline_job
    run_initial_build
    show_completion_info
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main