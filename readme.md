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

### Detailed Kubernetes Setup

#### 1. Firebase Configuration (Optional)

If you're using Firebase for push notifications:

```bash
# 1. Download your Firebase service account JSON from Firebase Console
# 2. Place it at: ./docker/firebase/service-account.json
# 3. Update the Kubernetes secret:
./kubernetes/update-firebase.sh
```

#### 2. Environment Configuration

The application configuration is managed through Kubernetes ConfigMaps and Secrets:

- **ConfigMap** (`app-configmap.yaml`): Non-sensitive configuration
- **Secrets** (`app-secret.yaml`): Database credentials, API keys, etc.

Update the configuration files as needed before deployment.

##### Switching Between Environments

To deploy different environments (develop/staging/production), update the image in `kubernetes/app-deployment.yaml`:

```yaml
# For Development
image: josemokeni/lecoursier-laravel-develop:latest

# For Staging
image: josemokeni/lecoursier-laravel-staging:latest

# For Production
image: josemokeni/lecoursier-laravel:latest
```

You may also need to update environment-specific variables in the ConfigMap and Secrets files.

#### 3. Persistent Storage

The setup includes persistent volumes for:

- **PostgreSQL**: 10GB for database data
- **Redis**: 5GB for cache persistence
- **pgAdmin**: 2GB for pgAdmin configuration

#### 4. Resource Allocation

Each service has defined resource limits:

- **PostgreSQL**: 1 CPU, 1GB RAM
- **Redis**: 500m CPU, 512MB RAM
- **Laravel App**: 500m CPU, 512MB RAM (2 replicas)
- **MailHog**: 200m CPU, 256MB RAM
- **Redis Commander**: 200m CPU, 256MB RAM
- **pgAdmin**: 500m CPU, 512MB RAM

### Management Commands

#### View Deployment Status

```bash
# Check all pods
kubectl get pods

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# Check persistent volumes
kubectl get pv,pvc
```

#### Logs and Debugging

```bash
# View application logs
kubectl logs -l app=lecoursier -f

# View specific service logs
kubectl logs -l app=postgres -f
kubectl logs -l app=redis -f

# Execute commands in application pod
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- bash
```

#### Database Management

##### Database Migrations

**Initial Setup (First Deployment):**

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=lecoursier --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# Run initial migrations
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate --force

# Seed database (if needed)
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan db:seed --force
```

**Running Migrations After Updates:**

```bash
# Check migration status
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate:status

# Run pending migrations
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate --force

# Rollback migrations (if needed)
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate:rollback --force
```

**Database Backup and Restore:**

```bash
# Create database backup
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- pg_dump -U postgres lecoursier-local-kubernetes > backup.sql

# Restore database from backup
kubectl exec -i $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres lecoursier-local-kubernetes < backup.sql
```

**Direct Database Access:**

```bash
# Connect to PostgreSQL directly via command line
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -d lecoursier-local-kubernetes

# Or use pgAdmin web interface at http://pgadmin.kubernetes
# Default credentials: admin@example.com / admin (change in pgadmin-secret.yaml)
```

**Migration Troubleshooting:**

```bash
# Check database connection from app
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan tinker --execute="DB::connection()->getPdo();"

# Check database tables
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -d lecoursier-local-kubernetes -c "\dt"

# Reset migrations (DANGER: Will drop all tables)
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate:fresh --force
```

#### Application Management

**Laravel Artisan Commands:**

```bash
# Get the application pod name (for convenience)
APP_POD=$(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}')

# Application maintenance
kubectl exec -it $APP_POD -- php artisan down
kubectl exec -it $APP_POD -- php artisan up

# Cache management
kubectl exec -it $APP_POD -- php artisan cache:clear
kubectl exec -it $APP_POD -- php artisan config:cache
kubectl exec -it $APP_POD -- php artisan route:cache
kubectl exec -it $APP_POD -- php artisan view:cache

# Queue management
kubectl exec -it $APP_POD -- php artisan queue:work --daemon
kubectl exec -it $APP_POD -- php artisan queue:restart

# Storage and file management
kubectl exec -it $APP_POD -- php artisan storage:link

# Generate application key (if needed)
kubectl exec -it $APP_POD -- php artisan key:generate --force
```

### Updating the Application

#### Update Application Image

```bash
# Update the image in app-deployment.yaml
# Then apply the changes:
kubectl apply -f kubernetes/app-deployment.yaml

# Or restart the deployment to pull latest image:
kubectl rollout restart deployment/lecoursier-app
```

#### Update Configuration

```bash
# After modifying ConfigMaps or Secrets:
kubectl apply -f kubernetes/app-configmap.yaml
kubectl apply -f kubernetes/app-secret.yaml

# Restart the application to pick up changes:
kubectl rollout restart deployment/lecoursier-app
```

### Scaling

#### Scale Application

```bash
# Scale to 3 replicas
kubectl scale deployment lecoursier-app --replicas=3

# Scale to 1 replica
kubectl scale deployment lecoursier-app --replicas=1
```

### Cleanup

```bash
# Delete all resources
kubectl delete -f kubernetes/

# Or delete specific resources
kubectl delete deployment,service,configmap,secret,pvc,ingress -l app=lecoursier
```

### Production Considerations

For production deployment, consider:

1. **External Database**: Use managed PostgreSQL service
2. **External Redis**: Use managed Redis service
3. **Image Registry**: Use private container registry
4. **SSL/TLS**: Configure proper SSL certificates
5. **Monitoring**: Add monitoring and logging solutions
6. **Backup**: Implement backup strategies for persistent data
7. **Security**: Review and harden security configurations
8. **Resource Limits**: Adjust resource allocations based on load testing

### Troubleshooting

#### Common Issues

**Pods not starting:**

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Ingress not working:**

```bash
# Check if Ingress controller is running
kubectl get pods -n ingress-nginx

# Check Ingress configuration
kubectl describe ingress lecoursier-ingress
```

**Database connection issues:**

```bash
# Check if PostgreSQL is running
kubectl get pods -l app=postgres

# Check service endpoints
kubectl get endpoints postgres-service

# Test database connection from app
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan tinker --execute="DB::connection()->getPdo();"

# Check database exists
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -c "\l"
```

**Migration issues:**

```bash
# Check migration status
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate:status

# Force run migrations
kubectl exec -it $(kubectl get pods -l app=lecoursier -o jsonpath='{.items[0].metadata.name}') -- php artisan migrate --force

# Check if migrations table exists
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -d lecoursier-local-kubernetes -c "\dt migrations"
```

**Storage issues:**

```bash
# Check persistent volumes
kubectl get pv,pvc

# Check storage class
kubectl get storageclass
```
