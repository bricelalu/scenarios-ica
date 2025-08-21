#!/bin/bash

# Wait for background installation to complete
echo "Waiting for background setup to complete..."

# Wait for Kubernetes to be ready
while ! kubectl get nodes >/dev/null 2>&1; do
    echo "Waiting for Kubernetes to be ready..."
    sleep 5
done

# Wait for Istio to be installed
while ! kubectl get namespace istio-system >/dev/null 2>&1; do
    echo "Waiting for Istio namespace to be created..."
    sleep 5
done

# Wait for Istio pods to be ready
echo "Waiting for Istio pods to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/istiod -n istio-system
kubectl wait --for=condition=available --timeout=600s deployment/istio-ingressgateway -n istio-system

echo "Background setup completed successfully!"