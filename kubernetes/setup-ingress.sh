#!/bin/bash

# Ingress Controller Comparison and Setup Script
# This script helps you choose and deploy the right ingress controller

set -e

echo "🔀 LeCoursier Kubernetes Ingress Controller Setup"
echo "=================================================="
echo ""
echo "Choose your ingress controller:"
echo ""
echo "1) 🌐 Nginx Ingress (Simple, Local Development)"
echo "   ✅ Quick setup for local development"
echo "   ✅ Works with local domains (*.kubernetes)"
echo "   ❌ Manual SSL certificate management"
echo "   ❌ No built-in dashboard"
echo ""
echo "2) 🚀 Traefik Ingress (Production, Auto HTTPS)"
echo "   ✅ Automatic SSL certificates from Let's Encrypt"
echo "   ✅ Built-in dashboard and monitoring"
echo "   ✅ Production-ready with advanced features"
echo "   ❌ Requires real domain names and public IP"
echo ""

read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "🌐 Setting up Nginx Ingress..."
        echo ""
        echo "Prerequisites:"
        echo "• Minikube with ingress addon enabled"
        echo "• Local /etc/hosts entries"
        echo ""
        read -p "Continue with Nginx setup? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo "🚀 Deploying with Nginx ingress..."
            ./deploy.sh
            echo ""
            echo "✅ Setup complete!"
            echo "📝 Next steps:"
            echo "1. Run: ./setup-hosts.sh (to add local DNS entries)"
            echo "2. Access: http://lecoursier.kubernetes"
        else
            echo "❌ Setup cancelled."
        fi
        ;;
    2)
        echo ""
        echo "🚀 Setting up Traefik Ingress..."
        echo ""
        echo "Prerequisites:"
        echo "• Real domain names pointing to your cluster"
        echo "• Public IP accessible from internet"
        echo "• Valid email for Let's Encrypt"
        echo ""
        echo "⚠️  Required Configuration:"
        echo "1. Update traefik-config.yaml with your email"
        echo "2. Update traefik-ingress.yaml with your domains"
        echo "3. Configure DNS A records"
        echo ""
        read -p "Have you completed the configuration? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo "🚀 Deploying with Traefik ingress..."
            ./deploy-traefik.sh
            echo ""
            echo "✅ Setup complete!"
            echo "📝 Next steps:"
            echo "1. Check Traefik dashboard for certificate status"
            echo "2. Access your services via HTTPS"
            echo "3. Monitor logs: kubectl logs -l app=traefik -f"
        else
            echo "❌ Setup cancelled."
            echo ""
            echo "📋 Configuration Checklist:"
            echo "□ Edit kubernetes/traefik-config.yaml"
            echo "  → Change email: your-email@example.com"
            echo ""
            echo "□ Edit kubernetes/traefik-ingress.yaml"
            echo "  → Replace example.com with your domain"
            echo ""
            echo "□ Configure DNS A records:"
            echo "  → lecoursier.yourdomain.com  → CLUSTER_IP"
            echo "  → mailhog.yourdomain.com     → CLUSTER_IP"
            echo "  → redis.yourdomain.com       → CLUSTER_IP"
            echo "  → pgadmin.yourdomain.com     → CLUSTER_IP"
            echo ""
            echo "Run this script again after configuration."
        fi
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📚 For more information, check the README.md file."
