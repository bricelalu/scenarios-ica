# Configuring mTLS Authentication with PeerAuthentication

In this step, you'll learn how to configure mutual TLS (mTLS) authentication using PeerAuthentication policies to secure service-to-service communication within the mesh.

## Understanding PeerAuthentication

PeerAuthentication enables:
- **Mutual TLS**: Both client and server authenticate each other
- **Service identity**: Cryptographic identity for each workload
- **Traffic encryption**: All inter-service communication is encrypted
- **Certificate management**: Automatic certificate lifecycle management
- **Fine-grained control**: Per-namespace, per-service, or per-port configuration

## Enable Strict mTLS Globally

Apply strict mTLS for the entire mesh:

```bash
kubectl apply -f /tmp/peer-auth-strict-mtls.yaml
```{{exec}}

View the global mTLS policy:

```bash
kubectl get peerauthentication default -n istio-system -o yaml
```{{exec}}

## Verify mTLS Status

Check mTLS status for all workloads:

```bash
istioctl authn tls-check $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}').default.svc.cluster.local
```{{exec}}

Check certificates in use:

```bash
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq '.'
```{{exec}}

## Test mTLS Communication

Test that services can still communicate with mTLS:

```bash
# Test productpage to reviews communication
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1

# Test sleep to httpbin communication
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/headers | jq '.headers'
```{{exec}}

## Apply Namespace-Level mTLS Policy

Create namespace-specific mTLS configuration:

```bash
kubectl apply -f /tmp/peer-auth-namespace.yaml
```{{exec}}

View namespace policy:

```bash
kubectl get peerauthentication namespace-policy -o yaml
```{{exec}}

## Create Workload-Specific mTLS Policy

Apply mTLS policy to specific workloads:

```bash
kubectl apply -f /tmp/peer-auth-workload.yaml
```{{exec}}

View workload-specific policy:

```bash
kubectl get peerauthentication httpbin-peer-policy -o yaml
```{{exec}}

## Configure Permissive mTLS

Create a permissive mTLS policy that allows both mTLS and plaintext:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: permissive-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  mtls:
    mode: PERMISSIVE
EOF
```{{exec}}

## Test Permissive Mode

Test that both mTLS and plain text work:

```bash
# From mesh client (should use mTLS)
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1

# Check if mTLS is being used
istioctl proxy-config cluster $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --fqdn reviews.default.svc.cluster.local -o json | jq '.[0].transportSocket'
```{{exec}}

## Configure Port-Specific mTLS

Create port-specific mTLS policies:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-port-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
  portLevelMtls:
    8000:
      mode: PERMISSIVE
    9000:
      mode: DISABLE
EOF
```{{exec}}

## Verify Port-Level Configuration

Check port-specific mTLS configuration:

```bash
# Check listener configuration for httpbin
istioctl proxy-config listeners $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}') --port 8000 -o json | jq '.[0].filterChains[0].tlsContext'
```{{exec}}

## Create Custom mTLS Configuration

Configure mTLS with custom settings:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: ratings-custom-mtls
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  mtls:
    mode: STRICT
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ratings-mtls-dr
  namespace: default
spec:
  host: ratings.default.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
      caCertificates: /etc/ssl/certs/root-cert.pem
      clientCertificate: /etc/ssl/certs/cert-chain.pem
      privateKey: /etc/ssl/certs/key.pem
EOF
```{{exec}}

## Monitor Certificate Status

Check certificate details and rotation:

```bash
# View current certificates
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq -r '.certificates[0].cert_chain' | openssl x509 -noout -text | grep -A 2 "Subject:"

# Check certificate validity
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq -r '.certificates[0].cert_chain' | openssl x509 -noout -dates

# View certificate serial numbers
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq '.certificates[0].ca_cert[0]' | openssl x509 -noout -serial
```{{exec}}

## Test mTLS Failure Scenarios

Create scenarios to test mTLS enforcement:

```bash
# Deploy a non-mesh client
kubectl run non-mesh-client --image=curlimages/curl --restart=Never --command -- sleep 3650d

# Wait for pod to be ready
kubectl wait --for=condition=ready pod non-mesh-client --timeout=300s

# Try to access from non-mesh client (should fail with strict mTLS)
kubectl exec -it non-mesh-client -- curl -s http://productpage.default.svc.cluster.local:9080/productpage || echo "Access denied from non-mesh client as expected"
```{{exec}}

## Configure External Service mTLS

Configure mTLS for external services:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-mtls-service
spec:
  hosts:
  - secure-api.external.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: external-mtls-dr
spec:
  host: secure-api.external.com
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/ssl/client-certs/tls.crt
      privateKey: /etc/ssl/client-certs/tls.key
      caCertificates: /etc/ssl/ca-certs/ca.crt
EOF
```{{exec}}

## Debug mTLS Issues

Use istioctl to debug mTLS configuration:

```bash
# Check authentication policy status
istioctl authn tls-check $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}').default.svc.cluster.local

# View effective authentication policies
kubectl get peerauthentication --all-namespaces

# Check proxy configuration
istioctl proxy-config listeners $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --port 9080
```{{exec}}

## Monitor mTLS Metrics

Check mTLS-related metrics:

```bash
# View connection security metrics
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep -E "(tls|ssl)"

# Check certificate expiration metrics
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep cert

# View authentication metrics
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep authn
```{{exec}}

## Test Certificate Rotation

Simulate certificate rotation:

```bash
# Check current certificate serial number
CURRENT_SERIAL=$(kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq -r '.certificates[0].cert_chain' | openssl x509 -noout -serial)
echo "Current certificate serial: $CURRENT_SERIAL"

# Restart pod to trigger certificate refresh
kubectl delete pod -l app=productpage
kubectl wait --for=condition=ready pod -l app=productpage --timeout=300s

# Check if certificate has changed
NEW_SERIAL=$(kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/certs | jq -r '.certificates[0].cert_chain' | openssl x509 -noout -serial)
echo "New certificate serial: $NEW_SERIAL"
```{{exec}}

## Configure Migration Strategies

Create policies for gradual mTLS migration:

```bash
# Phase 1: Permissive mode
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: migration-phase1
  namespace: default
spec:
  selector:
    matchLabels:
      app: details
  mtls:
    mode: PERMISSIVE
EOF

# Test both mTLS and plaintext work
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s http://details:9080/details/1

# Phase 2: Strict mode
kubectl patch peerauthentication migration-phase1 --type='merge' -p='{"spec":{"mtls":{"mode":"STRICT"}}}'

# Test that only mTLS works
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s http://details:9080/details/1
```{{exec}}

## Validate mTLS Security

Perform security validation:

```bash
# Verify encryption is active
istioctl proxy-config cluster $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --fqdn reviews.default.svc.cluster.local -o json | jq '.[0].transportSocket.name'

# Check cipher suites
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/clusters | grep -A 5 -B 5 "ssl"

# Analyze security posture
istioctl analyze
```{{exec}}

## Clean Up

Remove test resources:

```bash
kubectl delete pod non-mesh-client --ignore-not-found=true
kubectl delete peerauthentication permissive-policy migration-phase1 --ignore-not-found=true
```{{exec}}

## Key Takeaways

- PeerAuthentication enables automatic mTLS between services
- mTLS provides both authentication and encryption
- Strict mode enforces mTLS for all traffic
- Permissive mode allows gradual migration
- Port-level policies provide fine-grained control
- Certificate rotation is handled automatically by Istio
- Always validate mTLS configuration with istioctl
- Monitor certificate expiration and rotation metrics

In the next step, you'll learn about JWT authentication with RequestAuthentication.