#!/bin/bash

echo "Setting up Istio observability environment..."
echo "This will install Istio 1.26.0 with telemetry v2 and observability addons"
echo ""
echo "Components being installed:"
echo "- Istio 1.26.0 with Telemetry v2 enabled"
echo "- Jaeger for distributed tracing"
echo "- Prometheus for metrics collection"
echo "- Grafana for dashboards"
echo "- Kiali for service topology visualization"
echo ""
echo "Please wait while the environment initializes..."

# Wait for background initialization
while [ ! -f /ks/.initfinished ]; do
  sleep 2
done

echo ""
echo "✅ Istio observability environment is ready!"
echo ""
echo "Verify the installation:"
echo "kubectl get pods -n istio-system"