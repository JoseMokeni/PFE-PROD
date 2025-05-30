#!/bin/bash

# Traefik Configuration Generator
# This script helps you configure Traefik with your domain and email

set -e

echo "⚙️  Traefik Configuration Generator"
echo "==================================="
echo ""

# Get user input
read -p "Enter your email for Let's Encrypt: " email
read -p "Enter your domain (e.g., mydomain.com): " domain

if [[ -z "$email" || -z "$domain" ]]; then
    echo "❌ Email and domain are required!"
    exit 1
fi

echo ""
echo "📝 Configuring Traefik with:"
echo "   Email: $email"
echo "   Domain: $domain"
echo ""

# Update traefik-config.yaml
echo "🔧 Updating traefik-config.yaml..."
sed -i.bak "s/your-email@example.com/$email/g" traefik-config.yaml

# Update traefik-ingress.yaml
echo "🔧 Updating traefik-ingress.yaml..."
sed -i.bak "s/example.com/$domain/g" traefik-ingress.yaml

echo "✅ Configuration updated!"
echo ""
echo "📋 DNS Configuration Required:"
echo "Add these A records to your DNS:"
echo ""
echo "   lecoursier.$domain  →  [YOUR_CLUSTER_EXTERNAL_IP]"
echo "   mailhog.$domain     →  [YOUR_CLUSTER_EXTERNAL_IP]"
echo "   redis.$domain       →  [YOUR_CLUSTER_EXTERNAL_IP]"
echo "   pgadmin.$domain     →  [YOUR_CLUSTER_EXTERNAL_IP]"
echo ""
echo "💡 Get your cluster external IP with:"
echo "   kubectl get service traefik  (after deployment)"
echo ""
echo "🚀 Ready to deploy! Run:"
echo "   ./deploy-traefik.sh"
echo ""
echo "📊 Access URLs after deployment:"
echo "   🚀 Application: https://lecoursier.$domain"
echo "   📧 Mailhog: https://mailhog.$domain"
echo "   🔴 Redis: https://redis.$domain"
echo "   🐘 pgAdmin: https://pgadmin.$domain"
echo "   📊 Traefik Dashboard: http://[CLUSTER_IP]:8080"

# Create backup info
echo ""
echo "💾 Backup files created:"
echo "   • traefik-config.yaml.bak"
echo "   • traefik-ingress.yaml.bak"
