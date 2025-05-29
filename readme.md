# Le Coursier Production

## Prerequisites

1. Docker with Docker Compose installed
2. Required services running (See PFE_SERVICES repository):
   - PostgreSQL
   - Redis
   - Soketi
   - MailHog (for email testing)
   - Traefik (reverse proxy with Let's Encrypt)
3. Environment variables set in `.env` file (see `.env.example` for reference)
4. Stripe account created (for payment processing): Create alse the subscription plans in the Stripe dashboard and set the stripe environment variables in the `.env` file.
5. Firebase account created (for push notifications): Create a Firebase project and set the Firebase environment variables in the `.env` file.
6. Firebase service account added to the project: Download the service account JSON file from Firebase and save the file in the docker/firebase directory with the name `service-account.json`.

## Getting Started with Docker Compose

### Multi-Environment Setup

The project supports three environments:

- **Production** (`app`): `lecoursier.josemokeni.cloud`
- **Staging** (`app-staging`): `lecoursier.staging.josemokeni.cloud`
- **Development** (`app-develop`): `lecoursier.develop.josemokeni.cloud`

Each environment has its own:

- Docker image: `josemokeni/lecoursier-laravel:latest`, `josemokeni/lecoursier-laravel-staging:latest`, `josemokeni/lecoursier-laravel-develop:latest`
- Environment file: `.env`, `.env.staging`, `.env.develop`
- Traefik routing configuration

### Setup Steps

1. Clone the repository
2. Navigate to the project directory
3. Copy the `.env.example` file to create environment-specific files:

```bash
cp .env.example .env
cp .env.example .env.staging
cp .env.example .env.develop
```

4. Update each environment file with appropriate variables for each environment

5. Run the following command to start all services:

```bash
docker compose up -d
```

6. Change the permissions of environment files:

```bash
docker compose exec app chmod 644 .env
docker compose exec app-staging chmod 644 .env.staging
docker compose exec app-develop chmod 644 .env.develop
```

7. Generate application keys for each environment:

```bash
# Production
docker compose exec app php artisan key:generate

# Staging
docker compose exec app-staging php artisan key:generate

# Development
docker compose exec app-develop php artisan key:generate
```

8. Run migrations for each environment:

```bash
# Production
docker compose exec app php artisan migrate

# Staging
docker compose exec app-staging php artisan migrate

# Development
docker compose exec app-develop php artisan migrate
```

### Environment-Specific Commands

Each environment can be managed independently:

```bash
# Production environment
docker compose exec app <command>

# Staging environment
docker compose exec app-staging <command>

# Development environment
docker compose exec app-develop <command>
```

### Automatic Updates with Watchtower

The Docker Compose setup includes **Watchtower** for automatic container updates:

- **Update Interval**: Every 10 seconds
- **Cleanup**: Automatically removes old images
- **Rolling Restart**: Updates containers one by one to minimize downtime
- **Label-based**: Only updates containers with `com.centurylinklabs.watchtower.enable=true`

Watchtower will automatically pull and deploy new images when they are pushed to the registry, ensuring your environments stay up-to-date.

## Kubernetes Deployment

### Prerequisites for Kubernetes

1. **Minikube** or any Kubernetes cluster
2. **kubectl** configured to communicate with your cluster
3. **Nginx Ingress Controller** enabled (for Minikube: `minikube addons enable ingress`)
4. **Firebase service account JSON file** (same as Docker setup)

### Kubernetes Services Included

The Kubernetes setup includes all necessary services:

- **PostgreSQL Database** - Persistent database with pgAdmin web interface
- **Redis Cache** - In-memory cache with Redis Commander web interface
- **MailHog** - Email testing service with web interface
- **Laravel Application** - Your main application (configurable for different environments)
- **Nginx Ingress** - Single entry point with host-based routing

**Note**: The Kubernetes setup is currently configured for the development environment (`josemokeni/lecoursier-laravel-develop:latest`). To deploy staging or production, update the image in `kubernetes/app-deployment.yaml` to:

- Staging: `josemokeni/lecoursier-laravel-staging:latest`
- Production: `josemokeni/lecoursier-laravel:latest`

### Quick Start with Kubernetes

1. **Clone and navigate to the project:**

```bash
git clone <repository-url>
cd PFE-PROD
```

2. **Prepare Firebase service account (if you have one):**

```bash
# Place your Firebase service account JSON file here:
# ./docker/firebase/service-account.json

# Update the Kubernetes secret with your Firebase credentials:
./kubernetes/update-firebase.sh
```

3. **Deploy all services:**

```bash
# Deploy all Kubernetes resources
./kubernetes/deploy.sh
```

4. **Setup local DNS (for development):**

```bash
# Add entries to /etc/hosts for local access
./kubernetes/setup-hosts.sh
```

5. **Access your services:**

- **Application**: http://lecoursier.kubernetes
- **MailHog**: http://mailhog.kubernetes
- **Redis Commander**: http://redis.kubernetes (admin/admin)
- **pgAdmin**: http://pgadmin.kubernetes (admin@pgadmin.com/admin)

## Traefik Ingress with Automatic HTTPS

### Overview

Traefik is a modern reverse proxy and load balancer that provides automatic HTTPS certificate management through Let's Encrypt integration. This setup eliminates the need for manual SSL certificate management.

### Benefits of Traefik

- **Automatic HTTPS**: Automatically obtains and renews SSL certificates from Let's Encrypt
- **Modern Dashboard**: Built-in web UI for monitoring and management
- **Service Discovery**: Automatically discovers new services and routes
- **Middleware Support**: Built-in compression, rate limiting, and security headers
- **Production Ready**: Excellent performance and reliability

### Prerequisites for Traefik Setup

1. **Domain Names**: You need actual domain names pointing to your cluster
2. **Public IP**: Your Kubernetes cluster must be accessible from the internet
3. **Valid Email**: Required for Let's Encrypt certificate registration
4. **Port Access**: Ports 80 and 443 must be accessible from the internet

### Traefik Deployment

#### 1. Update Configuration

Before deploying, update the following files:

**Update your email in `kubernetes/traefik-config.yaml`:**

```bash
# Edit the configuration file
vim kubernetes/traefik-config.yaml

# Change this line:
email: your-email@example.com  # Change to your actual email
```

**Update your domains in `kubernetes/traefik-ingress.yaml`:**

```bash
# Edit the ingress file
vim kubernetes/traefik-ingress.yaml

# Replace example.com with your actual domain:
# - lecoursier.example.com  →  lecoursier.yourdomain.com
# - mailhog.example.com    →  mailhog.yourdomain.com
# - redis.example.com      →  redis.yourdomain.com
# - pgadmin.example.com    →  pgadmin.yourdomain.com
```

#### 2. Deploy with Traefik

```bash
# Deploy all services with Traefik
./kubernetes/deploy-traefik.sh
```

#### 3. DNS Configuration

Point your domain names to your cluster's external IP:

```bash
# Get your cluster's external IP
kubectl get service traefik

# Add DNS A records:
# lecoursier.yourdomain.com  →  CLUSTER_EXTERNAL_IP
# mailhog.yourdomain.com     →  CLUSTER_EXTERNAL_IP
# redis.yourdomain.com       →  CLUSTER_EXTERNAL_IP
# pgadmin.yourdomain.com     →  CLUSTER_EXTERNAL_IP
```

### Traefik Management

#### Access Traefik Dashboard

```bash
# Get Traefik service details
kubectl get service traefik

# Access dashboard at:
# http://CLUSTER_EXTERNAL_IP:8080
# or
# kubectl port-forward service/traefik 8080:8080
# Then access: http://localhost:8080
```

#### Monitor SSL Certificates

```bash
# Check certificate status in Traefik dashboard
# OR check ingress status
kubectl describe ingress lecoursier-traefik-ingress

# Check Traefik logs for certificate issues
kubectl logs -l app=traefik -f
```

#### SSL Certificate Troubleshooting

```bash
# Check ACME (Let's Encrypt) storage
kubectl exec -it $(kubectl get pods -l app=traefik -o jsonpath='{.items[0].metadata.name}') -- ls -la /data/

# View certificate details
kubectl exec -it $(kubectl get pods -l app=traefik -o jsonpath='{.items[0].metadata.name}') -- cat /data/acme.json

# Force certificate renewal (delete acme.json to retry)
kubectl exec -it $(kubectl get pods -l app=traefik -o jsonpath='{.items[0].metadata.name}') -- rm /data/acme.json
kubectl rollout restart deployment traefik
```

### Traefik vs Nginx Ingress

| Feature               | Traefik                   | Nginx Ingress            |
| --------------------- | ------------------------- | ------------------------ |
| **Auto HTTPS**        | ✅ Built-in Let's Encrypt | ❌ Requires cert-manager |
| **Dashboard**         | ✅ Built-in web UI        | ❌ No built-in dashboard |
| **Configuration**     | ✅ Simple annotations     | ⚠️ Complex configuration |
| **Performance**       | ✅ Excellent              | ✅ Excellent             |
| **Service Discovery** | ✅ Automatic              | ⚠️ Manual configuration  |
| **Learning Curve**    | ✅ Easy                   | ⚠️ Moderate              |

### Production Considerations for Traefik

1. **DNS Challenge**: For wildcard certificates, use DNS challenge instead of HTTP:

```yaml
# In traefik-config.yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /data/acme.json
      dnsChallenge:
        provider: cloudflare # or your DNS provider
        delayBeforeCheck: 30
```

2. **Resource Scaling**: Adjust resources based on load:

```yaml
# In traefik-deployment.yaml
resources:
  limits:
    cpu: "1000m"
    memory: "512Mi"
  requests:
    cpu: "200m"
    memory: "256Mi"
```

3. **High Availability**: Run multiple Traefik replicas:

```yaml
# In traefik-deployment.yaml
spec:
  replicas: 3 # For high availability
```

4. **Monitoring**: Enable metrics and integrate with monitoring tools:

```yaml
# In traefik-config.yaml
metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
```

### Switching Between Ingress Controllers

If you want to switch back to Nginx ingress:

```bash
# Remove Traefik ingress
kubectl delete -f kubernetes/traefik-ingress.yaml

# Apply original Nginx ingress
kubectl apply -f kubernetes/ingress.yaml

# Or remove Traefik completely
kubectl delete -f kubernetes/traefik-deployment.yaml
kubectl delete -f kubernetes/traefik-service.yaml
kubectl delete -f kubernetes/traefik-config.yaml
kubectl delete -f kubernetes/traefik-rbac.yaml
```

### Traefik Service Access URLs

Once deployed with your actual domains:

- **🚀 Application**: `https://lecoursier.yourdomain.com`
- **📊 Traefik Dashboard**: `http://CLUSTER_IP:8080`
- **📧 Mailhog**: `https://mailhog.yourdomain.com`
- **🔴 Redis Commander**: `https://redis.yourdomain.com`
- **🐘 pgAdmin**: `https://pgadmin.yourdomain.com`

All services will automatically have SSL certificates from Let's Encrypt!

## Quick Reference

### Available Scripts

| Script                 | Purpose                                  | Usage                               |
| ---------------------- | ---------------------------------------- | ----------------------------------- |
| `setup-ingress.sh`     | Interactive ingress controller selection | `./kubernetes/setup-ingress.sh`     |
| `configure-traefik.sh` | Configure Traefik with your domain/email | `./kubernetes/configure-traefik.sh` |
| `deploy.sh`            | Deploy with Nginx ingress (local dev)    | `./kubernetes/deploy.sh`            |
| `deploy-traefik.sh`    | Deploy with Traefik ingress (production) | `./kubernetes/deploy-traefik.sh`    |
| `setup-hosts.sh`       | Add local DNS entries for Nginx          | `./kubernetes/setup-hosts.sh`       |
| `update-firebase.sh`   | Update Firebase credentials              | `./kubernetes/update-firebase.sh`   |

### Quick Setup Commands

**For Local Development (Nginx):**

```bash
cd kubernetes
./setup-ingress.sh  # Choose option 1
```

**For Production (Traefik):**

```bash
cd kubernetes
./configure-traefik.sh  # Configure your domain/email
./setup-ingress.sh      # Choose option 2
```

### Service URLs Summary

**With Nginx Ingress (Local):**

- Application: `http://lecoursier.kubernetes`
- MailHog: `http://mailhog.kubernetes`
- Redis Commander: `http://redis.kubernetes`
- pgAdmin: `http://pgadmin.kubernetes`

**With Traefik Ingress (Production):**

- Application: `https://lecoursier.yourdomain.com`
- MailHog: `https://mailhog.yourdomain.com`
- Redis Commander: `https://redis.yourdomain.com`
- pgAdmin: `https://pgadmin.yourdomain.com`
- Traefik Dashboard: `http://cluster-ip:8080`
