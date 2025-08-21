# Domain 3: Securing Workloads (25%)

Welcome to the **Securing Workloads** domain of the Istio Certified Associate exam. This domain represents **25% of the exam** and focuses on the essential security capabilities that make Istio a powerful platform for zero-trust networking and application security.

## Official ICA Competencies Covered

This scenario will teach you the following official ICA competencies:

✅ **Configuring Authorization**  
✅ **Configuring Authentication (mTLS, JWT)**  
✅ **Securing Edge Traffic with TLS**  

## What You'll Master

By completing this security-focused scenario, you will become proficient in:

1. **Authorization and Access Control**
   - AuthorizationPolicy for fine-grained access control
   - RBAC patterns (ALLOW and DENY policies)
   - Method-based, header-based, and source-based authorization
   - Namespace and workload-level security policies

2. **mTLS Authentication**
   - PeerAuthentication for mutual TLS configuration
   - Cluster, namespace, and workload-level mTLS policies
   - STRICT, PERMISSIVE, and DISABLE modes
   - Certificate management and rotation

3. **JWT Authentication**
   - RequestAuthentication for token validation
   - JWT issuer configuration and JWKS integration
   - Claims-based authorization rules
   - Token forwarding and audience validation

4. **TLS Edge Security**
   - Gateway TLS termination configuration
   - Certificate management for ingress traffic
   - SNI-based routing with TLS
   - Mutual TLS for edge-to-mesh communication

## Security Principles Demonstrated

This scenario implements key security principles:

- **Zero Trust**: Verify every request regardless of source
- **Defense in Depth**: Multiple layers of security controls
- **Principle of Least Privilege**: Grant minimal necessary access
- **Identity-Based Security**: Authentication and authorization based on workload identity

## Real-World Security Applications

These security skills enable:
- **Compliance** with security standards (PCI-DSS, SOC 2, etc.)
- **Regulatory requirements** (GDPR, HIPAA, etc.)
- **Multi-tenant security** in shared environments
- **API security** for microservices architectures
- **Edge security** for internet-facing applications

## Prerequisites

- Basic understanding of TLS/SSL concepts
- Familiarity with authentication vs authorization
- Knowledge of JWT tokens and claims
- Understanding of X.509 certificates

Let's secure your workloads with Istio's powerful security features!