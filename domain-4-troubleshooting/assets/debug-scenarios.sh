#!/bin/bash

# Debug scenarios script for Istio troubleshooting
echo "=== Istio Debug Scenarios ==="

# Function to create a problematic scenario
create_broken_scenario() {
    local scenario_name=$1
    echo "Creating broken scenario: $scenario_name"
    
    case $scenario_name in
        "sidecar-injection")
            # Create namespace without injection label
            kubectl create namespace broken-injection --dry-run=client -o yaml | kubectl apply -f -
            kubectl apply -f /tmp/httpbin.yaml -n broken-injection
            echo "Created namespace without sidecar injection"
            ;;
        "service-discovery")
            # Create service with wrong selector
            cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-service
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: nonexistent-app  # No pods match this selector
EOF
            echo "Created service with broken selector"
            ;;
        "certificate-issues")
            # Create gateway with expired/invalid certificate
            kubectl create secret tls expired-cert --key=<(echo "invalid") --cert=<(echo "invalid") -n istio-system --dry-run=client -o yaml | kubectl apply -f -
            echo "Created gateway with invalid certificate"
            ;;
        "resource-limits")
            # Create deployment with insufficient resources
            cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-starved
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-starved
  template:
    metadata:
      labels:
        app: resource-starved
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        resources:
          limits:
            memory: "10Mi"  # Very low memory limit
            cpu: "1m"       # Very low CPU limit
          requests:
            memory: "10Mi"
            cpu: "1m"
EOF
            echo "Created deployment with insufficient resources"
            ;;
        "network-policies")
            # Create restrictive network policy
            cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
            echo "Created restrictive network policy"
            ;;
        *)
            echo "Unknown scenario: $scenario_name"
            ;;
    esac
}

# Function to show common troubleshooting commands
show_troubleshooting_commands() {
    echo ""
    echo "=== Common Troubleshooting Commands ==="
    echo "1. Check Istio installation:"
    echo "   kubectl get pods -n istio-system"
    echo "   istioctl version"
    echo ""
    echo "2. Validate configuration:"
    echo "   istioctl analyze"
    echo "   istioctl analyze --all-namespaces"
    echo ""
    echo "3. Check proxy status:"
    echo "   istioctl proxy-status"
    echo "   istioctl proxy-config cluster <pod-name>"
    echo ""
    echo "4. Debug connectivity:"
    echo "   kubectl exec -it <pod> -- curl -v <service>"
    echo "   kubectl logs <pod> -c istio-proxy"
    echo ""
    echo "5. Check certificates:"
    echo "   istioctl authn tls-check <service>"
    echo "   kubectl exec <pod> -- curl localhost:15000/certs"
    echo ""
    echo "6. Monitor traffic:"
    echo "   kubectl exec <pod> -- curl localhost:15000/stats"
    echo "   kubectl exec <pod> -- curl localhost:15000/clusters"
    echo ""
}

# Function to simulate common issues
simulate_issue() {
    local issue_type=$1
    
    case $issue_type in
        "high-latency")
            echo "Simulating high latency..."
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: high-latency-simulation
  namespace: default
spec:
  hosts:
  - httpbin
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s
    route:
    - destination:
        host: httpbin
EOF
            ;;
        "intermittent-failures")
            echo "Simulating intermittent failures..."
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: intermittent-failures
  namespace: default
spec:
  hosts:
  - httpbin
  http:
  - fault:
      abort:
        percentage:
          value: 30
        httpStatus: 503
    route:
    - destination:
        host: httpbin
EOF
            ;;
        "certificate-expiry")
            echo "Simulating certificate expiry issues..."
            # This would typically involve creating certificates with very short validity
            echo "Certificate expiry simulation setup (requires manual cert creation)"
            ;;
        *)
            echo "Unknown issue type: $issue_type"
            ;;
    esac
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 [create-scenario|show-commands|simulate] [scenario-name|issue-type]"
    echo ""
    echo "Available scenarios:"
    echo "  - sidecar-injection"
    echo "  - service-discovery"
    echo "  - certificate-issues"
    echo "  - resource-limits"
    echo "  - network-policies"
    echo ""
    echo "Available simulations:"
    echo "  - high-latency"
    echo "  - intermittent-failures"
    echo "  - certificate-expiry"
    echo ""
    show_troubleshooting_commands
else
    case $1 in
        "create-scenario")
            create_broken_scenario $2
            ;;
        "show-commands")
            show_troubleshooting_commands
            ;;
        "simulate")
            simulate_issue $2
            ;;
        *)
            echo "Unknown command: $1"
            ;;
    esac
fi