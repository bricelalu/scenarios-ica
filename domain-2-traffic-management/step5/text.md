# Connecting In-Mesh Workloads to External Workloads and Services

In this step, you'll learn how to securely connect services within the mesh to external services using ServiceEntry, VirtualService, and DestinationRule configurations.

## Understanding External Service Connectivity

External service connections involve:
- **ServiceEntry**: Register external services in the service registry
- **VirtualService**: Route traffic to external services
- **DestinationRule**: Apply policies to external destinations
- **Sidecar**: Control egress traffic scope
- **Egress Gateway**: Secure and monitor outbound traffic

## Configure External Service Access

Apply the external service configuration:

```bash
kubectl apply -f /tmp/service-entry-external.yaml
```{{exec}}

View the ServiceEntry configuration:

```bash
kubectl get serviceentry -o yaml
```{{exec}}

## Test Direct External Access

Test direct access to external services:

```bash
# Test HTTP access to httpbin.org
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.org/ip

# Test HTTPS access to httpbin.org
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s https://httpbin.org/headers
```{{exec}}

## Register External HTTP Service

Create ServiceEntry for external HTTP service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
EOF
```{{exec}}

## Register External Database Service

Create ServiceEntry for external database:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-postgres
spec:
  hosts:
  - postgres.external.com
  ports:
  - number: 5432
    name: postgres
    protocol: TCP
  location: MESH_EXTERNAL
  resolution: DNS
  endpoints:
  - address: 203.0.113.1
EOF
```{{exec}}

## Configure External Service Routing

Create VirtualService for external service routing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-ext-routing
spec:
  hosts:
  - httpbin.org
  http:
  - match:
    - uri:
        prefix: "/status"
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
    timeout: 10s
  - match:
    - uri:
        prefix: "/delay"
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
  - route:
    - destination:
        host: httpbin.org
        port:
          number: 80
EOF
```{{exec}}

## Apply External Service Policies

Configure DestinationRule for external services:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-ext-policies
spec:
  host: httpbin.org
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
        connectTimeout: 30s
      http:
        http1MaxPendingRequests: 5
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutiveGatewayErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
EOF
```{{exec}}

## Test External Service Policies

Test the configured policies:

```bash
# Test timeout configuration
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.org/delay/5

# Test retry configuration
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.org/status/500

# Generate load to test connection pooling
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..20}; do curl -s http://httpbin.org/get & done
```{{exec}}

## Configure Egress Gateway

Create egress gateway for external services:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.org
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - httpbin.org
    tls:
      mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: direct-httpbin-through-egress-gateway
spec:
  hosts:
  - httpbin.org
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
      weight: 100
EOF
```{{exec}}

## Test Egress Gateway Routing

Test traffic routing through egress gateway:

```bash
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.org/ip
```{{exec}}

Check egress gateway logs:

```bash
kubectl logs -l istio=egressgateway -n istio-system --tail=20
```{{exec}}

## Configure TLS Origination

Configure TLS origination at the egress gateway:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: istio-egressgateway-tls
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 443
      name: tls-origination
      protocol: HTTP
    hosts:
    - httpbin.org
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: egressgateway-for-httpbin
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: httpbin
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: originate-tls-for-httpbin
spec:
  host: httpbin.org
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    portLevelSettings:
    - port:
        number: 443
      tls:
        mode: SIMPLE
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: direct-httpbin-through-egress-gateway-tls
spec:
  hosts:
  - httpbin.org
  gateways:
  - istio-egressgateway-tls
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: httpbin
        port:
          number: 443
  - match:
    - gateways:
      - istio-egressgateway-tls
      port: 443
    route:
    - destination:
        host: httpbin.org
        port:
          number: 443
EOF
```{{exec}}

## Configure Wildcard External Services

Create ServiceEntry for wildcard domains:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: wildcard-google-apis
spec:
  hosts:
  - "*.googleapis.com"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
EOF
```{{exec}}

## Test Wildcard Services

Test access to wildcard services:

```bash
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s https://storage.googleapis.com --connect-timeout 10
```{{exec}}

## Monitor External Service Traffic

Check proxy configuration for external services:

```bash
# View external service clusters
istioctl proxy-config cluster $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --fqdn httpbin.org

# View external service endpoints
istioctl proxy-config endpoints $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --cluster "outbound|80||httpbin.org"

# View listeners for external traffic
istioctl proxy-config listeners $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --port 80
```{{exec}}

## Restrict External Access

Configure Sidecar to limit external access:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: restrict-external-access
spec:
  workloadSelector:
    labels:
      app: sleep
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
    - "httpbin.org"
EOF
```{{exec}}

## Test Access Restrictions

Test that access is now restricted:

```bash
# Should work - httpbin.org is allowed
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s --connect-timeout 5 http://httpbin.org/ip

# Should fail or timeout - google.com is not allowed
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s --connect-timeout 5 http://google.com || echo "Access blocked as expected"
```{{exec}}

## Key Takeaways

- ServiceEntry registers external services in the mesh
- VirtualService routes traffic to external destinations
- DestinationRule applies policies to external services
- Egress Gateway secures and monitors outbound traffic
- TLS origination can be performed at the egress gateway
- Sidecar configuration can restrict external access
- Always monitor external service traffic for security

In the next step, you'll learn about resilience features like circuit breaking and failover.