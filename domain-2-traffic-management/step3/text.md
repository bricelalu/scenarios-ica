# Defining Traffic Policies with DestinationRule

In this step, you'll learn how to use DestinationRule to define traffic policies including load balancing, connection pool settings, and service subsets for version management.

## Understanding DestinationRule

DestinationRule configures:
- **Service subsets**: Different versions of a service
- **Load balancing policies**: Round robin, least conn, random, passthrough
- **Connection pool settings**: HTTP/TCP connection limits
- **TLS settings**: mTLS configuration for destinations
- **Outlier detection**: Circuit breaking for unhealthy instances

## Apply Service Subsets

Create DestinationRule to define service subsets:

```bash
kubectl apply -f /tmp/destination-rule-policies.yaml
```{{exec}}

View the DestinationRule configuration:

```bash
kubectl get destinationrule -o yaml
```{{exec}}

## Test Load Balancing Policies

Create DestinationRule with different load balancing policies:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-load-balancer
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: RANDOM
  - name: v3
    labels:
      version: v3
    trafficPolicy:
      loadBalancer:
        simple: PASSTHROUGH
EOF
```{{exec}}

## Configure Connection Pool Settings

Apply connection pool settings for performance tuning:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-connection-pool
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
        connectTimeout: 30s
        keepAlive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 10
        http2MaxRequests: 100
        maxRequestsPerConnection: 10
        maxRetries: 3
        consecutiveGatewayErrors: 5
        interval: 30s
        baseEjectionTime: 30s
        maxEjectionPercent: 50
        minHealthPercent: 30
EOF
```{{exec}}

## Test Connection Pool Behavior

Generate load to test connection pooling:

```bash
# Deploy load testing tool
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fortio-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fortio
  template:
    metadata:
      labels:
        app: fortio
    spec:
      containers:
      - name: fortio
        image: fortio/fortio:latest_release
        ports:
        - containerPort: 8080
          name: http-fortio
        - containerPort: 8079
          name: grpc-ping
EOF
```{{exec}}

Wait for the deployment:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/fortio-deploy
```{{exec}}

Test with load:

```bash
kubectl exec -it $(kubectl get pod -l app=fortio -o jsonpath='{.items[0].metadata.name}') -- fortio load -c 5 -qps 50 -t 30s http://httpbin:8000/get
```{{exec}}

## Configure TLS Settings

Configure TLS settings for secure communication:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-tls
spec:
  host: httpbin.external.com
  trafficPolicy:
    tls:
      mode: SIMPLE
      sni: httpbin.external.com
      caCertificates: /etc/ssl/certs/ca-certificates.crt
EOF
```{{exec}}

## Configure Subset-Specific Policies

Create different policies for different service versions:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-subset-policies
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 5
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 10
      loadBalancer:
        simple: ROUND_ROBIN
  - name: v3
    labels:
      version: v3
    trafficPolicy:
      connectionPool:
        http:
          maxRequestsPerConnection: 1
      loadBalancer:
        simple: RANDOM
EOF
```{{exec}}

## Monitor Traffic Policy Effects

Check proxy configuration:

```bash
istioctl proxy-config cluster $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --fqdn reviews.default.svc.cluster.local
```{{exec}}

View endpoint configuration:

```bash
istioctl proxy-config endpoints $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --cluster "outbound|9080|v1|reviews.default.svc.cluster.local"
```{{exec}}

## Test Subset Routing

Create VirtualService to route to specific subsets:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-subset-routing
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - match:
    - headers:
        end-user:
          exact: alice
    route:
    - destination:
        host: reviews
        subset: v3
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```{{exec}}

## Validate Configuration

Analyze the complete traffic policy setup:

```bash
istioctl analyze
kubectl get destinationrule,virtualservice
```{{exec}}

Test routing to different subsets:

```bash
# Test routing to v1 (default)
curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 "reviews"

# Test routing to v2 (as jason)
curl -s "http://$GATEWAY_URL/productpage" -H "end-user: jason" | grep -A 5 "reviews"

# Test routing to v3 (as alice)  
curl -s "http://$GATEWAY_URL/productpage" -H "end-user: alice" | grep -A 5 "reviews"
```{{exec}}

## Key Takeaways

- DestinationRule defines traffic policies for destinations
- Supports load balancing, connection pooling, and TLS settings
- Service subsets enable version-based routing
- Policies can be applied globally or per-subset
- Connection pool settings help with performance tuning
- Always validate configuration with istioctl analyze

In the next step, you'll learn about traffic shifting and A/B testing strategies.