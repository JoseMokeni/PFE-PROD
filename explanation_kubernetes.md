# Kubernetes Deployment Explanation - LeCoursier Application

## Executive Summary

This document provides a comprehensive explanation of the Kubernetes deployment architecture implemented for the LeCoursier Laravel application. The deployment includes a complete microservices architecture with database, caching, message queuing, monitoring tools, and two ingress controller options for both development and production environments.

## Architecture Overview

The Kubernetes deployment consists of **7 main services** distributed across **multiple pods** with **persistent storage**, **service discovery**, and **ingress routing**. The architecture follows cloud-native best practices with proper separation of concerns, scalability, and security considerations.

### Deployment Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Ingress Layer                            │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │  Nginx Ingress  │     OR       │ Traefik Ingress │          │
│  │  (Development)  │              │  (Production)   │          │
│  └─────────────────┘              └─────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Application Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  LeCoursier App │  │   Redis Comm.   │  │     pgAdmin     │ │
│  │  (Laravel API)  │  │  (Monitoring)   │  │  (DB Manager)   │ │
│  │     Port 8080   │  │    Port 8081    │  │    Port 80      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │         │
│           ▼                     ▼                     ▼         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Data Layer                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   PostgreSQL    │  │      Redis      │  │     MailHog     │ │
│  │   (Database)    │  │    (Cache)      │  │  (Email Test)   │ │
│  │    Port 5432    │  │    Port 6379    │  │   Port 1025     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │         │
│           ▼                     ▼                     ▼         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Persistent     │  │  Persistent     │  │     Volumes     │ │
│  │   Volume        │  │   Volume        │  │   (Optional)    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Service Analysis

### 1. Application Services

#### 1.1 LeCoursier Laravel Application

- **Deployment**: `lecoursier-app`
- **Image**: `josemokeni/lecoursier-laravel-develop:latest`
- **Replicas**: 2 (High Availability)
- **Resource Allocation**:
  - CPU Limits: 500m (0.5 CPU cores)
  - Memory Limits: 512Mi
  - CPU Requests: 200m
  - Memory Requests: 256Mi
- **Port**: 8080
- **Configuration**: ConfigMap + Secrets for environment variables
- **Volumes**: Firebase service account mounted at `/var/www/html/storage/app/json`

**Technical Features**:

- Horizontal pod autoscaling ready
- Rolling deployment strategy
- Health checks and readiness probes
- Secure credential management via Kubernetes Secrets

#### 1.2 Configuration Management

- **ConfigMap** (`lecoursier-config`): Non-sensitive configuration
  - Database connection settings
  - Redis configuration
  - Application environment settings
- **Secrets** (`lecoursier-secrets`): Sensitive data
  - Database credentials
  - API keys
  - Firebase service account

### 2. Database Services

#### 2.1 PostgreSQL Database

- **Deployment**: `postgres`
- **Image**: `postgres:15`
- **Storage**: Persistent Volume Claim (10Gi)
- **Port**: 5432
- **Database**: `lecoursier-local-kubernetes`
- **Credentials**: Managed via Kubernetes Secrets

**Components**:

- `postgres-deployment.yaml`: Main database deployment
- `postgres-service.yaml`: Internal service (ClusterIP)
- `postgres-pvc.yaml`: Persistent volume for data storage
- `postgres-configmap.yaml`: Database configuration
- `postgres-secret.yaml`: Database credentials

**Features**:

- Data persistence across pod restarts
- Automatic backup capabilities
- Configurable via environment variables

#### 2.2 pgAdmin (Database Management)

- **Deployment**: `pgadmin`
- **Image**: `dpage/pgadmin4`
- **Port**: 80
- **Storage**: Persistent Volume Claim (1Gi)
- **Access**: Web-based database administration

**Authentication**:

- Email: `admin@example.com`
- Password: Stored in Kubernetes Secret
- Pre-configured connection to PostgreSQL

### 3. Caching and Queue Services

#### 3.1 Redis Cache

- **Deployment**: `redis`
- **Image**: `redis:7-alpine`
- **Storage**: Persistent Volume Claim (2Gi)
- **Port**: 6379
- **Configuration**: Custom redis.conf via ConfigMap

**Usage in Application**:

- Session storage
- Application caching
- Queue backend for Laravel jobs

#### 3.2 Redis Commander (Redis Management)

- **Deployment**: `redis-commander`
- **Image**: `rediscommander/redis-commander:latest`
- **Port**: 8081
- **Purpose**: Web-based Redis monitoring and management

**Features**:

- Real-time Redis monitoring
- Key-value inspection
- Memory usage analytics
- Performance metrics

### 4. Communication Services

#### 4.1 MailHog (Email Testing)

- **Deployment**: `mailhog`
- **Image**: `mailhog/mailhog`
- **Ports**:
  - SMTP: 1025 (internal)
  - Web UI: 8025 (external)
- **Purpose**: Email testing and debugging

**Components**:

- `mailhog-deployment.yaml`: Main service deployment
- `mailhog-service.yaml`: SMTP service (ClusterIP)
- `mailhog-web-service.yaml`: Web interface service

## Ingress and Routing

### Option 1: Nginx Ingress (Development)

**Purpose**: Local development with simple host-based routing

**Configuration**:

- **File**: `ingress.yaml`
- **Controller**: nginx
- **Domains**: `*.kubernetes` (local development)

**Routes**:

```yaml
lecoursier.kubernetes → lecoursier-service:80
mailhog.kubernetes    → mailhog-web-service:8025
redis.kubernetes      → redis-commander-service:8081
pgadmin.kubernetes    → pgadmin-service:80
```

**Features**:

- Simple setup for local development
- No SSL/TLS (HTTP only)
- Host file configuration required

### Option 2: Traefik Ingress (Production)

**Purpose**: Production deployment with automatic HTTPS

**Components**:

- `traefik-rbac.yaml`: RBAC permissions
- `traefik-config.yaml`: Traefik configuration with Let's Encrypt
- `traefik-deployment.yaml`: Traefik controller deployment
- `traefik-service.yaml`: LoadBalancer service
- `traefik-ingress.yaml`: Application routing
- `traefik-middlewares.yaml`: Security and performance middlewares
- `traefik-pvc.yaml`: Certificate storage

**Features**:

- **Automatic HTTPS**: Let's Encrypt integration
- **Certificate Management**: Automatic renewal
- **Dashboard**: Built-in monitoring at port 8080
- **Security**: Headers, rate limiting, compression
- **Production Ready**: High availability and performance

**SSL Certificate Management**:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /data/acme.json
      httpChallenge:
        entryPoint: web
```

## Storage Architecture

### Persistent Volumes

| Service    | Volume Name        | Size | Purpose           |
| ---------- | ------------------ | ---- | ----------------- |
| PostgreSQL | `postgres-pvc`     | 10Gi | Database storage  |
| Redis      | `redis-pvc`        | 2Gi  | Cache persistence |
| pgAdmin    | `pgadmin-pvc`      | 1Gi  | pgAdmin settings  |
| Traefik    | `traefik-acme-pvc` | 1Gi  | SSL certificates  |

**Storage Features**:

- **Persistence**: Data survives pod restarts
- **Dynamic Provisioning**: Automatic volume creation
- **Backup Ready**: Volumes can be backed up independently

## Security Implementation

### 1. Secrets Management

- Database credentials stored in Kubernetes Secrets
- Firebase service account securely mounted
- No sensitive data in ConfigMaps or deployment files

### 2. Network Security

- **ClusterIP Services**: Internal communication only
- **LoadBalancer**: Only for ingress controllers
- **Network Policies**: Can be implemented for additional isolation

### 3. RBAC (Role-Based Access Control)

- Service accounts with minimal required permissions
- Traefik controller has specific RBAC rules
- Principle of least privilege

### 4. Container Security

- Non-root user execution where possible
- Resource limits to prevent DoS
- Health checks for automatic recovery

## Deployment Scripts and Automation

### 1. Main Deployment Scripts

#### `deploy.sh` (Nginx Ingress)

```bash
#!/bin/bash
# Deploys all services with Nginx ingress
# Suitable for local development
```

**Deployment Order**:

1. PostgreSQL (database + storage)
2. Redis (cache + storage)
3. MailHog (email testing)
4. Redis Commander (monitoring)
5. pgAdmin (database management)
6. Firebase configuration
7. LeCoursier application
8. Nginx ingress

#### `deploy-traefik.sh` (Traefik Ingress)

```bash
#!/bin/bash
# Deploys all services with Traefik ingress
# Suitable for production with automatic HTTPS
```

**Deployment Order**:

1. Traefik RBAC and configuration
2. Traefik controller and services
3. All application services
4. Traefik ingress rules

### 2. Configuration Scripts

#### `configure-traefik.sh`

- Interactive configuration for domain and email
- Automatic file updates for production deployment
- DNS configuration guidance

#### `setup-ingress.sh`

- Interactive ingress controller selection
- Guided setup for both Nginx and Traefik
- Prerequisites checking

#### `setup-hosts.sh`

- Automatic `/etc/hosts` file configuration
- Local DNS entries for development
- Cross-platform compatibility

### 3. Maintenance Scripts

#### `update-firebase.sh`

- Secure Firebase credential management
- Kubernetes Secret updates
- Automatic pod restart for configuration pickup

## Environment Configuration

### Development Environment

- **Image**: `josemokeni/lecoursier-laravel-develop:latest`
- **Ingress**: Nginx with local domains
- **Storage**: Local persistent volumes
- **SSL**: Not required
- **Monitoring**: Basic logging

### Staging Environment

- **Image**: `josemokeni/lecoursier-laravel-staging:latest`
- **Ingress**: Traefik with staging domains
- **Storage**: Cloud persistent volumes
- **SSL**: Let's Encrypt staging certificates
- **Monitoring**: Full observability

### Production Environment

- **Image**: `josemokeni/lecoursier-laravel:latest`
- **Ingress**: Traefik with production domains
- **Storage**: Replicated cloud storage
- **SSL**: Let's Encrypt production certificates
- **Monitoring**: Comprehensive monitoring and alerting

## Monitoring and Observability

### 1. Built-in Dashboards

- **Traefik Dashboard**: Real-time routing and certificate status
- **pgAdmin**: Database monitoring and management
- **Redis Commander**: Cache performance and usage
- **MailHog**: Email delivery testing and debugging

### 2. Kubernetes Native Monitoring

- Pod status and health checks
- Resource usage monitoring
- Event logging and alerting
- Persistent volume monitoring

### 3. Application Monitoring

- Laravel logs accessible via `kubectl logs`
- Database connection monitoring
- Cache hit/miss ratios
- Email delivery status

## Scalability and Performance

### 1. Horizontal Scaling

```bash
# Scale application pods
kubectl scale deployment lecoursier-app --replicas=5

# Scale database (stateful scaling)
kubectl scale statefulset postgres --replicas=3
```

### 2. Resource Optimization

- **CPU/Memory limits**: Prevent resource exhaustion
- **Request/Limit ratios**: Optimal resource allocation
- **Pod affinity rules**: Distribute load across nodes

### 3. Performance Features

- **Redis caching**: Reduced database load
- **Connection pooling**: Efficient database connections
- **Compression**: Reduced bandwidth usage (Traefik)
- **HTTP/2**: Modern protocol support

## Backup and Disaster Recovery

### 1. Database Backup

```bash
# Manual backup
kubectl exec -it postgres-pod -- pg_dump -U postgres lecoursier > backup.sql

# Automated backup (via CronJob)
kubectl apply -f backup-cronjob.yaml
```

### 2. Volume Snapshots

- Persistent volume snapshots for point-in-time recovery
- Cross-region replication for disaster recovery
- Automated backup scheduling

### 3. Configuration Backup

- GitOps approach for configuration management
- Version-controlled deployment files
- Infrastructure as Code (IaC)

## Migration Guide

### From Docker Compose to Kubernetes

**Key Differences**:

1. **Service Discovery**: Environment variables → Kubernetes Services
2. **Storage**: Bind mounts → Persistent Volumes
3. **Networking**: Docker networks → Kubernetes Services
4. **Configuration**: .env files → ConfigMaps/Secrets
5. **Scaling**: Manual → Automatic horizontal scaling

**Migration Steps**:

1. Export Docker Compose configurations
2. Create Kubernetes manifests
3. Migrate persistent data
4. Update application configuration
5. Test service connectivity
6. Implement monitoring

## Best Practices Implemented

### 1. Container Best Practices

- ✅ Non-root user execution
- ✅ Minimal base images (Alpine Linux)
- ✅ Health checks and readiness probes
- ✅ Resource limits and requests
- ✅ Security contexts

### 2. Kubernetes Best Practices

- ✅ Namespace isolation
- ✅ Service accounts with minimal permissions
- ✅ ConfigMaps for non-sensitive data
- ✅ Secrets for sensitive data
- ✅ Rolling deployment strategy
- ✅ Pod disruption budgets

### 3. Security Best Practices

- ✅ No hardcoded credentials
- ✅ Network segmentation
- ✅ RBAC implementation
- ✅ Container image scanning
- ✅ Regular security updates

### 4. Operational Best Practices

- ✅ Infrastructure as Code
- ✅ Automated deployments
- ✅ Monitoring and alerting
- ✅ Backup and recovery procedures
- ✅ Documentation and runbooks

## Troubleshooting Guide

### Common Issues and Solutions

1. **Pod Startup Issues**

   - Check resource availability
   - Verify image pull policies
   - Review configuration and secrets

2. **Database Connection Issues**

   - Verify service endpoints
   - Check network policies
   - Validate credentials

3. **SSL Certificate Issues** (Traefik)

   - Verify DNS configuration
   - Check Let's Encrypt rate limits
   - Review ACME challenge logs

4. **Performance Issues**
   - Monitor resource usage
   - Check persistent volume performance
   - Review application logs

## Conclusion

This Kubernetes deployment provides a robust, scalable, and production-ready platform for the LeCoursier Laravel application. The architecture supports both development and production environments with appropriate tools and configurations for each use case.

**Key Achievements**:

- ✅ Complete microservices architecture
- ✅ Automatic HTTPS with Let's Encrypt
- ✅ Persistent data storage
- ✅ Built-in monitoring and management tools
- ✅ Scalable and fault-tolerant design
- ✅ Security best practices implementation
- ✅ Automated deployment and configuration

The deployment is ready for production use and can be easily scaled, monitored, and maintained using standard Kubernetes practices and tools.

---

**Document Version**: 1.0  
**Last Updated**: May 29, 2025  
**Author**: Technical Documentation Team  
**Review Status**: Technical Review Complete

## Autoscaling Implementation

### Overview

The LeCoursier application now includes comprehensive autoscaling capabilities to handle varying loads automatically while optimizing resource utilization and maintaining high availability.

### Autoscaling Components

#### 1. Horizontal Pod Autoscaler (HPA)

- **File**: `app-hpa.yaml`
- **Purpose**: Automatically scales the number of pod replicas based on resource utilization
- **Configuration**:
  - **Min Replicas**: 2 (High Availability)
  - **Max Replicas**: 10 (Cost Control)
  - **CPU Threshold**: 70% (Scale up when average CPU exceeds 70%)
  - **Memory Threshold**: 80% (Scale up when average memory exceeds 80%)
  - **Scale Up Behavior**: Maximum 100% increase or 2 pods per 60 seconds
  - **Scale Down Behavior**: Maximum 50% decrease per 5 minutes (stabilization)

**Features**:

- Prevents rapid oscillation with stabilization windows
- Dual metrics (CPU + Memory) for comprehensive scaling decisions
- Conservative scaling policies for production stability

#### 2. Vertical Pod Autoscaler (VPA)

- **File**: `app-vpa.yaml`
- **Purpose**: Automatically optimizes CPU and memory requests/limits
- **Configuration**:
  - **Update Mode**: Auto (automatically applies recommendations)
  - **CPU Range**: 100m - 1000m
  - **Memory Range**: 128Mi - 1Gi
  - **Controlled Values**: Both requests and limits

**Benefits**:

- Right-sizes containers based on actual usage patterns
- Reduces resource waste and improves cost efficiency
- Automatically adapts to application behavior changes

#### 3. Pod Disruption Budget (PDB)

- **File**: `app-pdb.yaml`
- **Purpose**: Ensures high availability during scaling operations
- **Configuration**:
  - **Min Available**: 1 pod always running
  - **Prevents**: Simultaneous termination of all pods during updates

#### 4. Enhanced Health Checks

- **Simplified Setup**: Minimal configuration for basic functionality
- **Benefits**: Ensures stable pod lifecycle during scaling operations

### Autoscaling Management

#### Management Script

A comprehensive management script is provided: `manage-autoscaling.sh`

**Available Commands**:

```bash
# Complete setup with prerequisites
./manage-autoscaling.sh setup

# Deploy autoscaling components
./manage-autoscaling.sh deploy

# Check current status and metrics
./manage-autoscaling.sh status

# Run load test to trigger scaling
./manage-autoscaling.sh test

# Remove autoscaling components
./manage-autoscaling.sh remove

# Show monitoring commands
./manage-autoscaling.sh monitor
```

#### Prerequisites Installation

The script automatically handles:

- **Metrics Server**: Required for HPA functionality
- **VPA Controller**: Optional but recommended for resource optimization
- **Configuration Validation**: Ensures proper setup

#### Monitoring and Observability

**Real-time Monitoring**:

```bash
# Watch scaling in real-time
watch kubectl get pods,hpa

# View detailed metrics
kubectl top pods -l app=lecoursier

# Check autoscaling events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i scale
```

**Key Metrics Tracked**:

- Pod replica count
- CPU and memory utilization
- Scaling events and decisions
- Resource recommendations (VPA)

### Integration with Deployment Scripts

Autoscaling is automatically included in both deployment options:

#### Nginx Deployment (Development)

```bash
./deploy.sh  # Now includes HPA, PDB, and health checks
```

#### Traefik Deployment (Production)

```bash
./deploy-traefik.sh  # Now includes HPA, PDB, and health checks
```

### Autoscaling Behavior Examples

#### Scale Up Scenario

1. **Trigger**: Application load increases, CPU usage > 70%
2. **Action**: HPA adds 1-2 new pods (max 100% increase)
3. **Stabilization**: Waits 60 seconds before next scaling decision
4. **Deployment**: New pods are deployed and become available

#### Scale Down Scenario

1. **Trigger**: Application load decreases, CPU usage < 70% for 5 minutes
2. **Action**: HPA removes pods gradually (max 50% decrease)
3. **Protection**: PDB ensures minimum 1 pod always available
4. **Grace Period**: Pods are gracefully terminated

### Production Considerations

#### Resource Optimization

- **Initial Sizing**: Requests set at 200m CPU, 256Mi memory
- **VPA Recommendations**: Continuously optimized based on actual usage
- **Limits**: Prevent resource hogging (500m CPU, 512Mi memory)

#### High Availability

- **Minimum Replicas**: Always maintain at least 2 pods
- **Pod Disruption Budget**: Prevents complete service outages
- **Graceful Scaling**: Ensures smooth scaling operations

#### Cost Management

- **Maximum Replicas**: Limited to 10 pods (configurable)
- **Efficient Scaling**: VPA prevents over-provisioning
- **Stabilization**: Prevents unnecessary scaling oscillations

### Troubleshooting

#### Common Issues and Solutions

**HPA Shows "Unknown" Metrics**:

```bash
# Check metrics server
kubectl get pods -n kube-system | grep metrics-server

# For Minikube, add insecure TLS flag
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

**Pods Not Scaling**:

```bash
# Verify resource requests are set
kubectl describe deployment lecoursier-app | grep -A 10 Resources

# Check HPA status
kubectl describe hpa lecoursier-app-hpa
```

### Advanced Features

#### Load Testing

Built-in load testing capability to validate autoscaling behavior:

```bash
./manage-autoscaling.sh test
```

This autoscaling implementation ensures your LeCoursier application can:

- **Scale automatically** based on real-time demand
- **Maintain high availability** during scaling operations
- **Optimize resource usage** for cost efficiency
- **Handle traffic spikes** without manual intervention
- **Provide consistent performance** under varying loads
