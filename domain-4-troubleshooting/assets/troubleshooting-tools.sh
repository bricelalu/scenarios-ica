#!/bin/bash

# Istio Troubleshooting Tools Script
# This script provides common troubleshooting commands for quick reference

echo "=== Istio Troubleshooting Tools ==="
echo

# Function to check overall cluster health
check_cluster_health() {
    echo "🔍 Checking Cluster Health..."
    echo "Kubernetes nodes:"
    kubectl get nodes
    echo
    echo "Istio system pods:"
    kubectl get pods -n istio-system
    echo
    echo "Proxy status:"
    istioctl proxy-status
    echo
}

# Function to analyze configurations
analyze_config() {
    echo "🔍 Analyzing Configuration..."
    istioctl analyze --all-namespaces
    echo
}

# Function to check sidecar injection
check_injection() {
    echo "🔍 Checking Sidecar Injection..."
    kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
    echo
}

# Function to test connectivity
test_connectivity() {
    local source_pod=$1
    local target_service=$2
    local target_port=$3
    
    echo "🔍 Testing Connectivity from $source_pod to $target_service:$target_port..."
    kubectl exec -it $source_pod -- curl -I http://$target_service:$target_port
    echo
}

# Function to check mTLS status
check_mtls() {
    local pod=$1
    local service=$2
    
    echo "🔍 Checking mTLS status for $service..."
    istioctl authn tls-check $pod $service
    echo
}

# Function to get proxy configuration
get_proxy_config() {
    local pod=$1
    local config_type=$2  # listeners, routes, clusters, endpoints, secrets
    
    echo "🔍 Getting $config_type configuration for $pod..."
    istioctl proxy-config $config_type $pod
    echo
}

# Function to check certificates
check_certificates() {
    local pod=$1
    
    echo "🔍 Checking certificates for $pod..."
    istioctl proxy-config secret $pod
    echo
}

# Function to get proxy logs with filtering
get_proxy_logs() {
    local pod=$1
    local filter=$2
    
    echo "🔍 Getting proxy logs for $pod (filter: $filter)..."
    if [ -z "$filter" ]; then
        kubectl logs $pod -c istio-proxy --tail=20
    else
        kubectl logs $pod -c istio-proxy --tail=50 | grep -i $filter
    fi
    echo
}

# Function to check security policies
check_security_policies() {
    echo "🔍 Checking Security Policies..."
    echo "PeerAuthentication:"
    kubectl get peerauthentication -A
    echo
    echo "RequestAuthentication:"
    kubectl get requestauthentication -A
    echo
    echo "AuthorizationPolicy:"
    kubectl get authorizationpolicy -A
    echo
}

# Function to enable debug logging
enable_debug() {
    local pod=$1
    local component=$2  # debug, rbac:debug, jwt:debug
    
    echo "🔍 Enabling $component logging for $pod..."
    istioctl proxy-config log $pod --level $component
    echo
}

# Main menu
case "$1" in
    "health")
        check_cluster_health
        ;;
    "analyze")
        analyze_config
        ;;
    "injection")
        check_injection
        ;;
    "connectivity")
        test_connectivity $2 $3 $4
        ;;
    "mtls")
        check_mtls $2 $3
        ;;
    "config")
        get_proxy_config $2 $3
        ;;
    "certs")
        check_certificates $2
        ;;
    "logs")
        get_proxy_logs $2 $3
        ;;
    "security")
        check_security_policies
        ;;
    "debug")
        enable_debug $2 $3
        ;;
    *)
        echo "Usage: $0 {health|analyze|injection|connectivity|mtls|config|certs|logs|security|debug}"
        echo
        echo "Examples:"
        echo "  $0 health                              # Check overall cluster health"
        echo "  $0 analyze                            # Analyze configurations"
        echo "  $0 injection                          # Check sidecar injection"
        echo "  $0 connectivity sleep productpage 9080  # Test connectivity"
        echo "  $0 mtls sleep-pod productpage.default.svc.cluster.local  # Check mTLS"
        echo "  $0 config productpage-pod listeners    # Get proxy config"
        echo "  $0 certs productpage-pod              # Check certificates"
        echo "  $0 logs productpage-pod error         # Get filtered logs"
        echo "  $0 security                           # Check security policies"
        echo "  $0 debug productpage-pod rbac:debug   # Enable debug logging"
        ;;
esac