# DevOps Pipeline Setup Guide

## Prerequisites

- Ubuntu 22.04 LTS or compatible Linux distribution
- Minimum 8GB RAM, 4 CPU cores
- 50GB available disk space
- Internet connection for downloading packages
- Non-root user with sudo privileges

## Quick Setup

Run the automated setup script:

```bash
chmod +x scripts/setup-linux.sh
./scripts/setup-linux.sh
```

This script will install and configure:
- Docker and Docker Compose
- Kubernetes (kind cluster)
- Jenkins CI/CD server
- ArgoCD for GitOps
- Trivy security scanner
- Prometheus and Grafana monitoring
- AWS CLI

## Manual Configuration Steps

### 1. Jenkins Configuration

1. Access Jenkins at `http://localhost:8080`
2. Use the initial admin password from `jenkins-credentials.txt`
3. Install recommended plugins plus:
   - Docker Pipeline
   - Kubernetes CLI
   - GitHub Integration
   - Pipeline: Stage View

4. Configure credentials:
   - Docker registry credentials
   - GitHub token
   - Kubeconfig file

### 2. ArgoCD Configuration

1. Access ArgoCD at `http://localhost:30080`
2. Login with username `admin` and password from `argocd-credentials.txt`
3. Add your Git repository
4. Create applications using the manifests in `argocd/`

### 3. AWS Configuration

Configure AWS CLI with your credentials:

```bash
aws configure
```

### 4. Docker Registry

Update the following files with your registry URL:
- `jenkins/Jenkinsfile`
- `k8s/dev/deployment.yaml`
- `k8s/prod/deployment.yaml`

## Environment Setup

### Development Environment

Deploy to development:

```bash
./scripts/deploy.sh dev
```

### Production Environment

Deploy to production:

```bash
./scripts/deploy.sh prod
```

## Monitoring Access

- **Prometheus**: `http://localhost:30090`
- **Grafana**: `http://localhost:30091` (admin/admin123)
- **ArgoCD**: `http://localhost:30080`
- **Jenkins**: `http://localhost:8080`

## Security Scanning

Trivy is configured to scan Docker images automatically in the CI/CD pipeline. Manual scanning:

```bash
trivy image your-registry.com/devops-flask-app:latest
```

## Backup and Recovery

### Database Backup

Run the backup script:

```bash
./scripts/backup-postgres.sh dev
```

### Disaster Recovery

1. Restore from S3 backup
2. Redeploy applications via ArgoCD
3. Verify service health

## Troubleshooting

### Common Issues

1. **Docker permission denied**
   - Log out and log back in after setup
   - Verify user is in docker group: `groups $USER`

2. **Kubernetes cluster not accessible**
   - Check kind cluster: `kind get clusters`
   - Verify kubectl context: `kubectl config current-context`

3. **Jenkins build failures**
   - Check Docker daemon is running
   - Verify credentials are configured
   - Check pipeline logs

4. **ArgoCD sync issues**
   - Verify Git repository access
   - Check application health in ArgoCD UI
   - Review sync policies

### Log Locations

- Jenkins: `/var/log/jenkins/jenkins.log`
- Docker: `journalctl -u docker.service`
- Kubernetes: `kubectl logs -n <namespace> <pod-name>`

## Pipeline Flow

1. **Code Commit** → GitHub repository
2. **Jenkins Trigger** → Webhook or polling
3. **Build & Test** → Run pytest, build Docker image
4. **Security Scan** → Trivy vulnerability assessment
5. **Image Push** → Docker registry
6. **GitOps Update** → Update Kubernetes manifests
7. **ArgoCD Sync** → Deploy to Kubernetes
8. **Health Check** → Verify deployment success
9. **Monitoring** → Prometheus metrics collection

## Best Practices

1. **Security**
   - Regularly update base images
   - Scan for vulnerabilities before deployment
   - Use non-root containers
   - Implement RBAC in Kubernetes

2. **Monitoring**
   - Set up alerts for critical metrics
   - Monitor application and infrastructure health
   - Implement distributed tracing

3. **Backup**
   - Automate database backups
   - Test recovery procedures regularly
   - Store backups in multiple locations

4. **GitOps**
   - Keep infrastructure as code
   - Use declarative configurations
   - Implement proper branching strategy