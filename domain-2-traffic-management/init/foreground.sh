#!/bin/bash

echo "Setting up Domain 2: Traffic Management Environment (35% of ICA Exam)..."
echo ""
echo "🎯 This is the LARGEST ICA domain - comprehensive traffic control mastery!"
echo ""
echo "🚦 Official ICA Competencies You'll Master:"
echo "  ✅ Configuring Ingress and Egress Traffic"
echo "  ✅ Configuring Routing within a Service Mesh"
echo "  ✅ Defining Traffic Policies with Destination Rules"
echo "  ✅ Configuring Traffic Shifting"
echo "  ✅ Connecting In-Mesh Workloads to External Services"
echo "  ✅ Using Resilience Features (circuit breaking, failover, outlier detection)"
echo "  ✅ Configuring Timeouts and Retries"
echo "  ✅ Using Fault Injection"
echo ""
echo "🏗️ Infrastructure Being Deployed:"
echo "  • Istio 1.26.0 with Ingress & Egress Gateways"
echo "  • Bookinfo microservices application (multiple versions)"
echo "  • httpbin service for HTTP testing"
echo "  • sleep client for traffic generation"
echo "  • External service simulator for ServiceEntry scenarios"
echo ""
echo "📈 Advanced Traffic Patterns You'll Learn:"
echo "  • Intelligent request routing (header-based, path-based)"
echo "  • Canary deployments and blue-green strategies"
echo "  • A/B testing with weighted traffic distribution"
echo "  • Circuit breakers and automatic failover"
echo "  • Chaos engineering with fault injection"
echo ""
echo "Please wait while we deploy the complete traffic management environment..."
echo "This includes multiple microservices, gateways, and testing tools."

# Wait for background initialization with progress indicators
counter=0
while [ ! -f /ks/.initfinished ]; do
  sleep 3
  case $((counter % 4)) in
    0) echo -n "🔄 Installing Istio and gateways..." ;;
    1) echo -n "📦 Deploying Bookinfo microservices..." ;;
    2) echo -n "🌐 Setting up external service connectors..." ;;
    3) echo -n "⚙️ Configuring traffic management resources..." ;;
  esac
  echo ""
  counter=$((counter + 1))
done

echo ""
echo "✅ Domain 2: Traffic Management Environment Ready!"
echo ""
echo "🎉 What you now have available:"
echo "  🌐 Ingress Gateway: External traffic entry point"
echo "  🚀 Egress Gateway: Controlled outbound traffic"
echo "  📚 Bookinfo App: Multi-service application with 3 review versions"
echo "  🧪 Testing Tools: httpbin and sleep for traffic generation"
echo "  🔗 External Services: Ready for ServiceEntry scenarios"
echo ""
echo "🎓 Learning Path:"
echo "  Step 1-2: Gateway configuration (ingress/egress)"
echo "  Step 3-4: Advanced routing and traffic policies"
echo "  Step 5: External service integration"
echo "  Step 6-8: Resilience, timeouts, and fault injection"
echo ""
echo "Let's master Istio traffic management - the core of service mesh! 🚀"