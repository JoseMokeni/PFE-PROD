# Kubernetes Autoscaling Implementation for LeCoursier Application

## Overview

This document explains how to implement and manage autoscaling for your LeCoursier Laravel application in Kubernetes. The implementation includes both Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA) for optimal resource utilization and performance.

## Table of Contents

1. [Autoscaling Types](#autoscaling-types)
2. [Prerequisites](#prerequisites)
3. [Quick Setup](#quick-setup)
4. [Configuration Details](#configuration-details)
5. [Monitoring and Testing](#monitoring-and-testing)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

## Autoscaling Types

### 1. Horizontal Pod Autoscaler (HPA)

- **Purpose**: Automatically scales the number of pod replicas
- **Triggers**: Based on CPU, memory, or custom metrics
- **Range**: 2-10 replicas (configurable)
- **File**: `app-hpa.yaml`

### 2. Vertical Pod Autoscaler (VPA)

- **Purpose**: Automatically adjusts CPU and memory requests/limits
- **Triggers**: Based on actual resource usage patterns
- **Range**: 100m-1000m CPU, 128Mi-1Gi memory
- **File**: `app-vpa.yaml`

### 3. Pod Disruption Budget (PDB)

- **Purpose**: Ensures minimum availability during scaling operations
- **Configuration**: Minimum 1 pod available at all times
- **File**: `app-pdb.yaml`

## Prerequisites

### Required Components

1. **Metrics Server**: Required for HPA to function
2. **Kubernetes 1.23+**: For autoscaling/v2 API
3. **Resource Requests/Limits**: Defined in deployment
4. **Health Checks**: Liveness and readiness probes

### Optional Components

1. **Vertical Pod Autoscaler**: For automatic resource optimization
2. **Prometheus**: For advanced metrics and monitoring
3. **Grafana**: For autoscaling dashboards

## Quick Setup

### Option 1: Automated Setup

```bash
# Navigate to kubernetes directory
cd kubernetes

# Run automated setup (installs all prerequisites)
./manage-autoscaling.sh setup
```

### Option 2: Manual Setup

```bash
# 1. Install metrics server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 2. For Minikube, add insecure TLS flag
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 3. Deploy autoscaling components
kubectl apply -f app-pdb.yaml
kubectl apply -f app-hpa.yaml

# 4. Optional: Deploy VPA (requires VPA controller)
kubectl apply -f app-vpa.yaml
```

### Option 3: Include in Deployment Scripts

Autoscaling is now automatically included in both deployment scripts:

```bash
# For Nginx ingress (development)
./deploy.sh

# For Traefik ingress (production)
./deploy-traefik.sh
```

## Configuration Details

### Horizontal Pod Autoscaler Configuration

```yaml
# app-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lecoursier-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lecoursier-app
  minReplicas: 2 # Minimum pods
  maxReplicas: 10 # Maximum pods
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70 # Scale up at 70% CPU
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80 # Scale up at 80% memory
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60 # Wait 60s before scaling up
      policies:
        - type: Percent
          value: 100 # Max 100% increase per scaling
          periodSeconds: 15
        - type: Pods
          value: 2 # Max 2 pods per scaling
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300 # Wait 5min before scaling down
      policies:
        - type: Percent
          value: 50 # Max 50% decrease per scaling
          periodSeconds: 60
```

### Key Configuration Parameters

| Parameter           | Value | Description                                |
| ------------------- | ----- | ------------------------------------------ |
| `minReplicas`       | 2     | Minimum number of pods (high availability) |
| `maxReplicas`       | 10    | Maximum number of pods (cost control)      |
| `CPU threshold`     | 70%   | Scale up when average CPU > 70%            |
| `Memory threshold`  | 80%   | Scale up when average memory > 80%         |
| `Scale up window`   | 60s   | Minimum time between scale up events       |
| `Scale down window` | 300s  | Minimum time between scale down events     |

### Vertical Pod Autoscaler Configuration

```yaml
# app-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: lecoursier-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lecoursier-app
  updatePolicy:
    updateMode: "Auto" # Automatically apply recommendations
  resourcePolicy:
    containerPolicies:
      - containerName: lecoursier-app
        minAllowed:
          cpu: 100m # Minimum CPU request
          memory: 128Mi # Minimum memory request
        maxAllowed:
          cpu: 1000m # Maximum CPU limit
          memory: 1Gi # Maximum memory limit
        controlledResources: ["cpu", "memory"]
        controlledValues: RequestsAndLimits
```

### Pod Disruption Budget

```yaml
# app-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: lecoursier-app-pdb
spec:
  minAvailable: 1 # Always keep at least 1 pod running
  selector:
    matchLabels:
      app: lecoursier
```

## Monitoring and Testing

### Viewing Autoscaling Status

```bash
# Check HPA status
kubectl get hpa
kubectl describe hpa lecoursier-app-hpa

# Check VPA status (if installed)
kubectl get vpa
kubectl describe vpa lecoursier-app-vpa

# Check current resource usage
kubectl top pods -l app=lecoursier
kubectl top nodes

# Watch scaling in real-time
watch kubectl get pods,hpa
```

### Testing Autoscaling

#### Option 1: Use Management Script

```bash
# Run automated load test
./manage-autoscaling.sh test
```

#### Option 2: Manual Load Testing

```bash
# Using Apache Bench (if available)
ab -n 10000 -c 50 -t 300 http://lecoursier.kubernetes/

# Using curl in a loop
for i in {1..300}; do
  for j in {1..10}; do
    curl -s http://lecoursier.kubernetes/ > /dev/null &
  done
  sleep 1
done
```

#### Option 3: Stress Test Pod

```bash
# Deploy a stress test pod
kubectl run stress-test --image=busybox --rm -it --restart=Never -- /bin/sh

# Inside the pod, run:
while true; do wget -q -O- http://lecoursier-service; done
```

### Monitoring Commands

```bash
# Real-time monitoring
watch kubectl get pods,hpa

# View autoscaling events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i scale

# View detailed HPA metrics
kubectl describe hpa lecoursier-app-hpa

# Check application logs during scaling
kubectl logs -l app=lecoursier -f

# Manual scaling (for testing)
kubectl scale deployment lecoursier-app --replicas=5
```

## Troubleshooting

### Common Issues

#### 1. HPA Shows "Unknown" Metrics

**Symptoms:**

```bash
kubectl get hpa
# Shows: TARGETS: <unknown>/70%
```

**Solutions:**

```bash
# Check if metrics server is running
kubectl get pods -n kube-system | grep metrics-server

# Check metrics server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# For Minikube, add insecure TLS flag
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

#### 2. Pods Not Scaling

**Check resource requests:**

```bash
kubectl describe deployment lecoursier-app | grep -A 10 Resources
```

**Verify HPA configuration:**

```bash
kubectl describe hpa lecoursier-app-hpa
```

#### 3. VPA Not Working

**Check if VPA is installed:**

```bash
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io
```

**Install VPA:**

```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
./hack/vpa-up.sh
```

#### 4. Scaling Events Not Triggered

**Check current resource usage:**

```bash
kubectl top pods -l app=lecoursier
```

**View HPA conditions:**

```bash
kubectl describe hpa lecoursier-app-hpa | grep Conditions -A 10
```

### Debugging Commands

```bash
# Check metrics availability
kubectl get --raw /metrics.k8s.io/v1beta1/nodes
kubectl get --raw /metrics.k8s.io/v1beta1/pods

# Check HPA controller logs
kubectl logs -n kube-system -l app=horizontal-pod-autoscaler

# Check VPA recommender logs
kubectl logs -n kube-system -l app=vpa-recommender

# Test metrics server directly
kubectl top nodes
kubectl top pods --all-namespaces
```

## Best Practices

### 1. Resource Configuration

✅ **Always set resource requests and limits:**

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "200m" # Required for HPA
    memory: "256Mi" # Required for HPA
```

✅ **Use realistic values based on actual usage:**

- Monitor your application for a few days
- Use VPA recommendations
- Set requests at 80% of typical usage
- Set limits at 150% of peak usage

### 2. Health Checks

✅ **Implement proper health checks:**

```yaml
livenessProbe:
  httpGet:
    path: /health # Or any health endpoint
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /ready # Or any readiness endpoint
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

### 3. Scaling Configuration

✅ **Conservative scaling to avoid oscillation:**

- Set reasonable thresholds (60-80% CPU)
- Use stabilization windows
- Start with small replica ranges (2-10)

✅ **Monitor and adjust:**

- Review scaling events regularly
- Adjust thresholds based on actual patterns
- Use custom metrics for business logic

### 4. Production Considerations

✅ **High Availability:**

```yaml
spec:
  minReplicas: 3 # Always >= 2 for HA
  maxReplicas: 50 # Adjust based on capacity
```

✅ **Pod Disruption Budget:**

```yaml
spec:
  minAvailable: 2 # Or use percentage: "50%"
```

✅ **Resource Limits:**

```yaml
resources:
  limits:
    cpu: "1000m" # Prevent resource hogging
    memory: "1Gi"
```

### 5. Monitoring and Alerting

✅ **Set up monitoring:**

- Monitor scaling events
- Track resource utilization
- Alert on scaling failures
- Monitor application performance during scaling

✅ **Use Prometheus metrics:**

```yaml
# ServiceMonitor for Prometheus
spec:
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
```

## Advanced Configuration

### Custom Metrics Autoscaling

For more sophisticated autoscaling based on application-specific metrics:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lecoursier-app-hpa-custom
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lecoursier-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: requests_per_second
        target:
          type: AverageValue
          averageValue: "100" # Scale when > 100 RPS per pod
    - type: Object
      object:
        metric:
          name: queue_length
        target:
          type: Value
          value: "100" # Scale when queue > 100 items
```

### Multi-Dimensional Autoscaling

```yaml
# Use both HPA and VPA together
# HPA for scaling replicas, VPA for optimizing resources
```

**Note:** VPA and HPA on CPU/memory should not be used together on the same deployment to avoid conflicts.

## Management Script Usage

The `manage-autoscaling.sh` script provides comprehensive autoscaling management:

```bash
# Complete setup with prerequisites
./manage-autoscaling.sh setup

# Deploy only autoscaling components
./manage-autoscaling.sh deploy

# Check current status
./manage-autoscaling.sh status

# Run load test
./manage-autoscaling.sh test

# Remove autoscaling
./manage-autoscaling.sh remove

# Show monitoring commands
./manage-autoscaling.sh monitor

# Help
./manage-autoscaling.sh help
```

## Integration with Existing Deployment

Autoscaling is now integrated into your existing deployment scripts:

### Nginx Deployment (Development)

```bash
./deploy.sh  # Includes HPA and PDB automatically
```

### Traefik Deployment (Production)

```bash
./deploy-traefik.sh  # Includes HPA and PDB automatically
```

Both scripts now automatically deploy:

- Pod Disruption Budget (PDB)
- Horizontal Pod Autoscaler (HPA)
- Health checks in the deployment

This ensures your application can scale efficiently while maintaining high availability.
