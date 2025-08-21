# Using Resilience Features - Circuit Breaking, Failover, Outlier Detection

In this step, you'll learn how to implement resilience patterns using Istio's circuit breaking, failover mechanisms, and outlier detection to build fault-tolerant distributed systems.

## Understanding Resilience Features

Resilience features include:
- **Circuit Breaking**: Prevent cascading failures by stopping calls to failing services
- **Outlier Detection**: Automatically remove unhealthy instances from load balancing pool
- **Failover**: Redirect traffic to healthy instances/regions
- **Load Balancing**: Distribute load efficiently across healthy instances
- **Health Checks**: Monitor service health proactively

## Apply Circuit Breaker Configuration

Deploy circuit breaker configuration:

```bash
kubectl apply -f /tmp/circuit-breaker.yaml
```{{exec}}

View the circuit breaker settings:

```bash
kubectl get destinationrule circuit-breaker -o yaml
```{{exec}}

## Test Circuit Breaker Behavior

Generate load to trigger circuit breaking:

```bash
# Create load testing deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-loadtest
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin-loadtest
  template:
    metadata:
      labels:
        app: httpbin-loadtest
        version: v1
    spec:
      containers:
      - name: loadtest
        image: fortio/fortio:latest_release
        command: ["/usr/bin/fortio"]
        args: ["server", "-http-port", "8080"]
        ports:
        - containerPort: 8080
EOF
```{{exec}}

Wait for load test pod:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/httpbin-loadtest
```{{exec}}

Trigger circuit breaker with excessive connections:

```bash
kubectl exec -it $(kubectl get pod -l app=httpbin-loadtest -o jsonpath='{.items[0].metadata.name}') -- fortio load -c 10 -qps 20 -t 30s http://httpbin:8000/get
```{{exec}}

## Configure Outlier Detection

Apply outlier detection configuration:

```bash
kubectl apply -f /tmp/outlier-detection.yaml
```{{exec}}

View outlier detection settings:

```bash
kubectl get destinationrule outlier-detection -o yaml
```{{exec}}

## Deploy Multiple Service Instances

Create multiple instances of httpbin for testing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
        # Simulate failing instance
        readinessProbe:
          httpGet:
            path: /status/500
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
EOF
```{{exec}}

## Test Outlier Detection

Monitor which instances receive traffic:

```bash
# Generate requests and observe outlier detection
for i in {1..50}; do
  kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/ip | grep origin
  sleep 0.5
done
```{{exec}}

Check proxy stats for outlier detection:

```bash
istioctl proxy-config cluster $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --fqdn httpbin.default.svc.cluster.local -o json | jq '.[0].outlierDetection'
```{{exec}}

## Configure Regional Failover

Create services in different failure domains:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-region-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin-regional
      region: us-east-1
  template:
    metadata:
      labels:
        app: httpbin-regional
        region: us-east-1
        version: v1
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-region-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin-regional
      region: us-west-2
  template:
    metadata:
      labels:
        app: httpbin-regional
        region: us-west-2
        version: v1
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin-regional
spec:
  selector:
    app: httpbin-regional
  ports:
  - port: 8000
    targetPort: 80
EOF
```{{exec}}

## Configure Failover Policy

Apply failover configuration:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-regional-failover
spec:
  host: httpbin-regional
  trafficPolicy:
    outlierDetection:
      consecutiveGatewayErrors: 2
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: region/us-east-1/*
          to:
            "region/us-east-1/*": 80
            "region/us-west-2/*": 20
        - from: region/us-west-2/*
          to:
            "region/us-west-2/*": 80
            "region/us-east-1/*": 20
        failover:
        - from: us-east-1
          to: us-west-2
        - from: us-west-2
          to: us-east-1
  subsets:
  - name: region-1
    labels:
      region: us-east-1
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 10
  - name: region-2
    labels:
      region: us-west-2
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 10
EOF
```{{exec}}

## Test Failover Behavior

Simulate regional failure and test failover:

```bash
# Scale down region-1 to simulate failure
kubectl scale deployment httpbin-region-1 --replicas=0

# Generate traffic to test failover
for i in {1..20}; do
  kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin-regional:8000/ip | grep origin
done
```{{exec}}

## Configure Advanced Circuit Breaker

Create sophisticated circuit breaker with multiple thresholds:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-advanced-circuit-breaker
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 5
        connectTimeout: 10s
        keepAlive:
          time: 7200s
          interval: 75s
          probes: 9
      http:
        http1MaxPendingRequests: 1
        http2MaxRequests: 5
        maxRequestsPerConnection: 3
        maxRetries: 2
        consecutiveGatewayErrors: 2
        interval: 10s
        baseEjectionTime: 30s
        maxEjectionPercent: 80
        minHealthPercent: 20
        useClientProtocol: true
    outlierDetection:
      consecutiveGatewayErrors: 3
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
      splitExternalLocalOriginErrors: true
EOF
```{{exec}}

## Load Test Advanced Circuit Breaker

Test the advanced circuit breaker:

```bash
# High concurrency test
kubectl exec -it $(kubectl get pod -l app=httpbin-loadtest -o jsonpath='{.items[0].metadata.name}') -- fortio load -c 15 -qps 30 -t 60s http://httpbin:8000/status/500

# Check circuit breaker stats
istioctl proxy-config cluster $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --fqdn httpbin.default.svc.cluster.local -o json | jq '.[0].circuitBreakers'
```{{exec}}

## Monitor Resilience Metrics

Check proxy statistics for resilience features:

```bash
# Get detailed cluster statistics
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep httpbin | grep -E "(upstream_rq_|outlier_detection|circuit_breaker)"

# Check cluster health status
istioctl proxy-config endpoints $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') --cluster "outbound|8000||httpbin.default.svc.cluster.local"
```{{exec}}

## Configure Health Checks

Add custom health checking:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-health-check
spec:
  host: httpbin
  trafficPolicy:
    healthCheck:
      path: "/status/200"
      intervalDuration: 10s
      timeoutDuration: 3s
      unhealthyThreshold: 3
      healthyThreshold: 2
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        http1MaxPendingRequests: 5
        consecutiveGatewayErrors: 3
    outlierDetection:
      consecutiveGatewayErrors: 3
      interval: 30s
      baseEjectionTime: 30s
EOF
```{{exec}}

## Test Complete Resilience Stack

Generate comprehensive resilience testing:

```bash
# Test with mixed traffic patterns
kubectl exec -it $(kubectl get pod -l app=httpbin-loadtest -o jsonpath='{.items[0].metadata.name}') -- fortio load -c 8 -qps 25 -t 45s -H "X-Test: resilience" http://httpbin:8000/anything

# Monitor all resilience features
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep -E "(circuit_breaker|outlier_detection|health_check|upstream_rq_pending|upstream_rq_retry)" | head -20
```{{exec}}

## Analyze Resilience Configuration

Review all resilience policies:

```bash
kubectl get destinationrule -o yaml | grep -A 30 -B 5 -E "(circuitBreakers|outlierDetection|healthCheck)"

# Validate configuration
istioctl analyze
```{{exec}}

## Key Takeaways

- Circuit breakers prevent cascading failures by limiting connections
- Outlier detection automatically removes unhealthy instances
- Failover policies enable regional disaster recovery
- Health checks provide proactive service monitoring  
- Connection pool settings control resource usage
- Combining multiple resilience features provides robust fault tolerance
- Always monitor resilience metrics in production

In the next step, you'll learn about configuring timeouts and retries.