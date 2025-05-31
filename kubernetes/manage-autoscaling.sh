#!/bin/bash

# Autoscaling Management Script for LeCoursier Application
# This script helps you manage and monitor autoscaling for your Kubernetes deployment

set -e

echo "🔄 LeCoursier Autoscaling Management"
echo "==================================="
echo ""

# Function to check if metrics server is installed
check_metrics_server() {
    if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
        echo "✅ Metrics server is installed"
        return 0
    else
        echo "❌ Metrics server is not installed"
        return 1
    fi
}

# Function to install metrics server
install_metrics_server() {
    echo "📊 Installing metrics server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # For minikube, we need to add insecure TLS flag
    if command -v minikube &> /dev/null && minikube status &>/dev/null; then
        echo "🔧 Configuring metrics server for Minikube..."
        kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    fi
    
    echo "⏳ Waiting for metrics server to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
    echo "✅ Metrics server installed successfully"
}

# Function to check if VPA is installed
check_vpa() {
    if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io &>/dev/null; then
        echo "✅ Vertical Pod Autoscaler is installed"
        return 0
    else
        echo "❌ Vertical Pod Autoscaler is not installed"
        return 1
    fi
}

# Function to install VPA
install_vpa() {
    echo "📈 Installing Vertical Pod Autoscaler..."
    git clone https://github.com/kubernetes/autoscaler.git /tmp/autoscaler
    cd /tmp/autoscaler/vertical-pod-autoscaler/
    ./hack/vpa-up.sh
    cd - > /dev/null
    rm -rf /tmp/autoscaler
    echo "✅ VPA installed successfully"
}

# Function to show current HPA status
show_hpa_status() {
    echo "📊 Current HPA Status:"
    echo "====================="
    if kubectl get hpa lecoursier-app-hpa &>/dev/null; then
        kubectl get hpa lecoursier-app-hpa
        echo ""
        kubectl describe hpa lecoursier-app-hpa
    else
        echo "❌ HPA not found"
    fi
    echo ""
}

# Function to show current VPA status
show_vpa_status() {
    echo "📈 Current VPA Status:"
    echo "====================="
    if kubectl get vpa lecoursier-app-vpa &>/dev/null; then
        kubectl get vpa lecoursier-app-vpa
        echo ""
        kubectl describe vpa lecoursier-app-vpa
    else
        echo "❌ VPA not found"
    fi
    echo ""
}

# Function to show pod resource usage
show_resource_usage() {
    echo "💾 Current Resource Usage:"
    echo "========================="
    kubectl top pods -l app=lecoursier
    echo ""
    kubectl top nodes
    echo ""
}

# Function to deploy autoscaling
deploy_autoscaling() {
    echo "🚀 Deploying autoscaling components..."
    
    echo "📦 Creating Pod Disruption Budget..."
    kubectl apply -f app-pdb.yaml
    
    echo "⚡ Creating Horizontal Pod Autoscaler..."
    kubectl apply -f app-hpa.yaml
    
    if check_vpa; then
        echo "📈 Creating Vertical Pod Autoscaler..."
        kubectl apply -f app-vpa.yaml
    else
        echo "⚠️  VPA not available, skipping VPA deployment"
    fi
    
    echo "✅ Autoscaling components deployed successfully!"
}

# Function to remove autoscaling
remove_autoscaling() {
    echo "🗑️  Removing autoscaling components..."
    
    kubectl delete -f app-hpa.yaml --ignore-not-found=true
    kubectl delete -f app-vpa.yaml --ignore-not-found=true
    kubectl delete -f app-pdb.yaml --ignore-not-found=true
    
    echo "✅ Autoscaling components removed"
}

# Function to test scaling
test_scaling() {
    echo "🧪 Testing autoscaling..."
    echo "This will generate load on your application to trigger autoscaling"
    echo ""
    
    # Get the service URL
    if kubectl get ingress lecoursier-ingress &>/dev/null; then
        URL="http://lecoursier.kubernetes"
    elif kubectl get ingress lecoursier-traefik-ingress &>/dev/null; then
        URL=$(kubectl get ingress lecoursier-traefik-ingress -o jsonpath='{.spec.rules[0].host}')
        URL="https://$URL"
    else
        URL="http://localhost:8080"
        echo "⚠️  No ingress found, using port-forward..."
        kubectl port-forward service/lecoursier-service 8080:80 &
        PORT_FORWARD_PID=$!
        sleep 5
    fi
    
    echo "🔗 Testing URL: $URL"
    echo "📊 Monitor scaling with: watch kubectl get pods,hpa"
    echo ""
    echo "🚀 Generating load for 5 minutes..."
    
    # Run load test using Apache Bench if available, otherwise use curl
    if command -v ab &> /dev/null; then
        ab -n 10000 -c 50 -t 300 "$URL/"
    else
        echo "⚠️  Apache Bench not found, using curl in loop..."
        for i in {1..300}; do
            for j in {1..10}; do
                curl -s "$URL/" > /dev/null &
            done
            sleep 1
            if [ $((i % 30)) -eq 0 ]; then
                echo "🕐 $i seconds elapsed..."
            fi
        done
        wait
    fi
    
    # Clean up port-forward if it was started
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    
    echo "✅ Load test completed"
    echo "📊 Check scaling results:"
    kubectl get pods,hpa
}

# Function to show monitoring commands
show_monitoring() {
    echo "📊 Monitoring Commands:"
    echo "======================"
    echo ""
    echo "# Watch pods and HPA in real-time:"
    echo "watch kubectl get pods,hpa"
    echo ""
    echo "# View detailed HPA events:"
    echo "kubectl describe hpa lecoursier-app-hpa"
    echo ""
    echo "# View pod resource usage:"
    echo "kubectl top pods -l app=lecoursier"
    echo ""
    echo "# View autoscaling events:"
    echo "kubectl get events --sort-by=.metadata.creationTimestamp | grep -i scale"
    echo ""
    echo "# View application logs:"
    echo "kubectl logs -l app=lecoursier -f"
    echo ""
    echo "# Manual scaling (for testing):"
    echo "kubectl scale deployment lecoursier-app --replicas=5"
    echo ""
}

# Main menu
case "$1" in
    "setup")
        echo "🔧 Setting up autoscaling prerequisites..."
        
        if ! check_metrics_server; then
            install_metrics_server
        fi
        
        if ! check_vpa; then
            read -p "Do you want to install Vertical Pod Autoscaler? (y/N): " install_vpa_choice
            if [[ $install_vpa_choice =~ ^[Yy]$ ]]; then
                install_vpa
            fi
        fi
        
        deploy_autoscaling
        ;;
    "deploy")
        echo "🚀 Deploying autoscaling components..."
        deploy_autoscaling
        ;;
    "remove")
        echo "🗑️  Removing autoscaling components..."
        remove_autoscaling
        ;;
    "status")
        echo "📊 Autoscaling Status:"
        echo "====================="
        echo ""
        show_hpa_status
        show_vpa_status
        show_resource_usage
        ;;
    "test")
        echo "🧪 Testing autoscaling..."
        test_scaling
        ;;
    "monitor")
        show_monitoring
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup    - Install prerequisites and deploy autoscaling"
        echo "  deploy   - Deploy autoscaling components"
        echo "  remove   - Remove autoscaling components"
        echo "  status   - Show current autoscaling status"
        echo "  test     - Run load test to trigger autoscaling"
        echo "  monitor  - Show monitoring commands"
        echo "  help     - Show this help message"
        ;;
    *)
        # Interactive menu when no arguments provided
        echo "Please select an option:"
        echo ""
        echo "1) 🔧 Setup (Install prerequisites and deploy autoscaling)"
        echo "2) 🚀 Deploy (Deploy autoscaling components)"
        echo "3) 📊 Status (Show current autoscaling status)"
        echo "4) 🧪 Test (Run load test to trigger autoscaling)"
        echo "5) 📊 Monitor (Show monitoring commands)"
        echo "6) 🗑️  Remove (Remove autoscaling components)"
        echo "7) ❓ Help (Show help message)"
        echo "8) 🚪 Exit"
        echo ""
        
        while true; do
            read -p "Enter your choice (1-8): " choice
            case $choice in
                1)
                    echo ""
                    echo "🔧 Setting up autoscaling prerequisites..."
                    
                    if ! check_metrics_server; then
                        install_metrics_server
                    fi
                    
                    if ! check_vpa; then
                        read -p "Do you want to install Vertical Pod Autoscaler? (y/N): " install_vpa_choice
                        if [[ $install_vpa_choice =~ ^[Yy]$ ]]; then
                            install_vpa
                        fi
                    fi
                    
                    deploy_autoscaling
                    break
                    ;;
                2)
                    echo ""
                    echo "🚀 Deploying autoscaling components..."
                    deploy_autoscaling
                    break
                    ;;
                3)
                    echo ""
                    echo "📊 Autoscaling Status:"
                    echo "====================="
                    echo ""
                    show_hpa_status
                    show_vpa_status
                    show_resource_usage
                    break
                    ;;
                4)
                    echo ""
                    echo "🧪 Testing autoscaling..."
                    test_scaling
                    break
                    ;;
                5)
                    echo ""
                    show_monitoring
                    break
                    ;;
                6)
                    echo ""
                    echo "🗑️  Removing autoscaling components..."
                    remove_autoscaling
                    break
                    ;;
                7)
                    echo ""
                    echo "Usage: $0 [command]"
                    echo ""
                    echo "Commands:"
                    echo "  setup    - Install prerequisites and deploy autoscaling"
                    echo "  deploy   - Deploy autoscaling components"
                    echo "  remove   - Remove autoscaling components"
                    echo "  status   - Show current autoscaling status"
                    echo "  test     - Run load test to trigger autoscaling"
                    echo "  monitor  - Show monitoring commands"
                    echo "  help     - Show this help message"
                    break
                    ;;
                8)
                    echo ""
                    echo "👋 Goodbye!"
                    break
                    ;;
                *)
                    echo "❌ Invalid choice. Please enter a number between 1-8."
                    ;;
            esac
        done
        ;;
esac
