#!/bin/bash

echo "Setting up Domain 3: Securing Workloads Environment (25% of ICA Exam)..."
echo ""
echo "🛡️ SECURITY DOMAIN - Zero Trust and Defense in Depth!"
echo ""
echo "🎯 Official ICA Security Competencies You'll Master:"
echo "  ✅ Configuring Authorization (RBAC, policies, access control)"
echo "  ✅ Configuring Authentication (mTLS, JWT token validation)"
echo "  ✅ Securing Edge Traffic with TLS (certificates, termination)"
echo ""
echo "🔐 Advanced Security Patterns:"
echo "  • Multi-tenant namespace isolation"
echo "  • Service-to-service mTLS authentication"
echo "  • JWT token-based authorization"
echo "  • Fine-grained access control with AuthorizationPolicy"
echo "  • TLS termination and certificate management"
echo ""
echo "🏗️ Security Infrastructure Being Deployed:"
echo "  • Multi-namespace environment (production, staging, external)"
echo "  • Service accounts with different roles (admin, user, viewer)"
echo "  • TLS certificates for edge security scenarios"
echo "  • JWT token server for authentication testing"
echo "  • Applications across security boundaries"
echo ""
echo "🔒 Security Layers You'll Implement:"
echo "  Layer 1: Network isolation with namespaces"
echo "  Layer 2: Transport security with mTLS"
echo "  Layer 3: Application authentication with JWT"
echo "  Layer 4: Fine-grained authorization policies"
echo "  Layer 5: Edge security with TLS termination"
echo ""
echo "Please wait while we deploy the comprehensive security environment..."
echo "Setting up multi-tenant infrastructure with security controls..."

# Wait for background initialization with security-focused progress
counter=0
while [ ! -f /ks/.initfinished ]; do
  sleep 3
  case $((counter % 5)) in
    0) echo -n "🔐 Installing Istio with security features..." ;;
    1) echo -n "🏢 Creating multi-tenant namespace environment..." ;;
    2) echo -n "👥 Setting up service accounts and RBAC..." ;;
    3) echo -n "🔑 Generating TLS certificates and secrets..." ;;
    4) echo -n "🎫 Deploying JWT authentication server..." ;;
  esac
  echo ""
  counter=$((counter + 1))
done

echo ""
echo "✅ Domain 3: Securing Workloads Environment Ready!"
echo ""
echo "🛡️ Security Infrastructure Available:"
echo "  🏢 Namespaces: default, production, staging, external"
echo "  👥 Service Accounts: admin-sa, user-sa, viewer-sa, httpbin"
echo "  🔑 TLS Certificates: Generated and stored as secrets"
echo "  🎫 JWT Server: Available for token-based authentication"
echo "  📱 Test Applications: Deployed across security boundaries"
echo ""
echo "🎓 Security Learning Path:"
echo "  Step 1: Authorization policies and access control"
echo "  Step 2: mTLS configuration and mutual authentication"
echo "  Step 3: JWT authentication and token validation"
echo "  Step 4: Advanced authorization patterns (namespace, RBAC)"
echo "  Step 5: TLS edge security and certificate management"
echo ""
echo "🚨 Security Principle: Zero Trust Architecture"
echo "   'Never trust, always verify' - every request authenticated & authorized"
echo ""
echo "Ready to secure your service mesh! 🛡️🚀"