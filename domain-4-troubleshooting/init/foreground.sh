#!/bin/bash

echo "Setting up Istio troubleshooting environment..."
echo "This scenario will teach you systematic troubleshooting techniques"
echo ""
echo "Components being prepared:"
echo "- Istio 1.26.0 with demo profile"
echo "- Sample applications (Bookinfo, httpbin, sleep)"
echo "- Intentionally broken configurations for practice"
echo "- Comprehensive troubleshooting tools and scripts"
echo ""
echo "Please wait while the environment initializes..."

# Wait for background initialization
while [ ! -f /ks/.initfinished ]; do
  sleep 2
done

echo ""
echo "✅ Troubleshooting environment is ready!"
echo ""
echo "Verify the installation:"
echo "kubectl get pods -n istio-system"
echo "kubectl get pods -l istio-injection=enabled"