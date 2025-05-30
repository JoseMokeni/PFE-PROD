#!/bin/bash

# Deploy Kubernetes resources in correct order

echo "Creating Persistent Volume Claims..."
kubectl apply -f postgres-pvc.yaml
kubectl apply -f redis-pvc.yaml
kubectl apply -f pgadmin-pvc.yaml

echo "Creating ConfigMaps..."
kubectl apply -f postgres-configmap.yaml
kubectl apply -f redis-configmap.yaml
kubectl apply -f app-configmap.yaml

echo "Creating Secrets..."
kubectl apply -f postgres-secret.yaml
kubectl apply -f pgadmin-secret.yaml
kubectl apply -f firebase-secret.yaml
kubectl apply -f app-secret.yaml

echo "Creating Services..."
kubectl apply -f postgres-service.yaml
kubectl apply -f redis-service.yaml
kubectl apply -f mailhog-service.yaml
kubectl apply -f mailhog-web-service.yaml
kubectl apply -f redis-commander-service.yaml
kubectl apply -f pgadmin-service.yaml
kubectl apply -f app-service.yaml

echo "Creating Deployments..."
kubectl apply -f postgres-deployment.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f mailhog-deployment.yaml
kubectl apply -f redis-commander-deployment.yaml
kubectl apply -f pgadmin-deployment.yaml

echo "Waiting for database, Redis, Mailhog, Redis Commander, and pgAdmin to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s
kubectl wait --for=condition=ready pod -l app=mailhog --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-commander --timeout=300s
kubectl wait --for=condition=ready pod -l app=pgadmin --timeout=300s

echo "Creating Application Deployment..."
kubectl apply -f app-deployment.yaml

echo "Creating Ingress..."
kubectl apply -f ingress.yaml

echo "Waiting for application to be ready..."
kubectl wait --for=condition=ready pod -l app=lecoursier --timeout=300s

echo "All resources deployed successfully!"
echo ""
echo "To check the status of your pods, run:"
echo "kubectl get pods"
echo ""
echo "To view services, run:"
echo "kubectl get services"
echo ""
echo "To view ingress, run:"
echo "kubectl get ingress"
echo ""
echo "To access your application:"
echo "Add the following to your /etc/hosts file:"
echo "$(minikube ip) lecoursier.kubernetes"
echo "$(minikube ip) mailhog.kubernetes"
echo "$(minikube ip) redis.kubernetes"
echo "$(minikube ip) pgadmin.kubernetes"
echo ""
echo "Then access:"
echo "- Application: http://lecoursier.kubernetes"
echo "- Mailhog: http://mailhog.kubernetes"
echo "- Redis Commander: http://redis.kubernetes (admin/admin)"
echo "- pgAdmin: http://pgadmin.kubernetes (admin@pgadmin.com/admin)"
