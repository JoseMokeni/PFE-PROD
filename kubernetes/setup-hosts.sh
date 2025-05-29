#!/bin/bash

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo "Minikube IP: $MINIKUBE_IP"
echo ""
echo "Adding entries to /etc/hosts..."

# Check if entries already exist
if grep -q "lecoursier.kubernetes" /etc/hosts; then
    echo "Updating existing lecoursier.kubernetes entry..."
    sudo sed -i "s/.*lecoursier.kubernetes/$MINIKUBE_IP lecoursier.kubernetes/" /etc/hosts
else
    echo "Adding new lecoursier.kubernetes entry..."
    echo "$MINIKUBE_IP lecoursier.kubernetes" | sudo tee -a /etc/hosts
fi

if grep -q "mailhog.kubernetes" /etc/hosts; then
    echo "Updating existing mailhog.kubernetes entry..."
    sudo sed -i "s/.*mailhog.kubernetes/$MINIKUBE_IP mailhog.kubernetes/" /etc/hosts
else
    echo "Adding new mailhog.kubernetes entry..."
    echo "$MINIKUBE_IP mailhog.kubernetes" | sudo tee -a /etc/hosts
fi

if grep -q "redis-commander.kubernetes" /etc/hosts; then
    echo "Updating existing redis.kubernetes entry..."
    sudo sed -i "s/.*redis.kubernetes/$MINIKUBE_IP redis.kubernetes/" /etc/hosts
else
    echo "Adding new redis.kubernetes entry..."
    echo "$MINIKUBE_IP redis.kubernetes" | sudo tee -a /etc/hosts
fi

if grep -q "pgadmin.kubernetes" /etc/hosts; then
    echo "Updating existing pgadmin.kubernetes entry..."
    sudo sed -i "s/.*pgadmin.kubernetes/$MINIKUBE_IP pgadmin.kubernetes/" /etc/hosts
else
    echo "Adding new pgadmin.kubernetes entry..."
    echo "$MINIKUBE_IP pgadmin.kubernetes" | sudo tee -a /etc/hosts
fi

echo ""
echo "Hosts file updated successfully!"
echo ""
echo "You can now access:"
echo "- Application: http://lecoursier.kubernetes"
echo "- Mailhog: http://mailhog.kubernetes"
echo "- Redis Commander: http://redis.kubernetes (admin/admin)"
echo "- pgAdmin: http://pgadmin.kubernetes (admin@pgadmin.com/admin)"
echo ""
echo "To check ingress status:"
echo "kubectl get ingress"
