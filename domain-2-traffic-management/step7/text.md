# Configuring Timeouts and Retries for Resilient Communication

Timeouts and retries are essential resilience features that prevent cascading failures and improve service reliability. This is a specific competency in the Traffic Management domain that frequently appears in ICA exams.

## Understanding Timeouts and Retries

**Timeouts** prevent requests from hanging indefinitely when services are unresponsive.
**Retries** automatically retry failed requests to handle transient network issues.

Both are configured in **VirtualService** and **DestinationRule** resources.

## Setting Up Test Environment

Let's verify our services are running:

```plain
kubectl get pods -l app=reviews
```{{exec}}

```plain
kubectl get pods -l app=ratings
```{{exec}}

```plain
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
echo $SLEEP_POD
```{{exec}}

## Configuring Request Timeouts

### VirtualService Timeout Configuration

Create a VirtualService with timeout settings:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-timeout
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
    timeout: 2s  # Timeout after 2 seconds
EOF
```{{exec}}

### Test Timeout Behavior

First, let's test normal response time:

```plain
kubectl exec -it $SLEEP_POD -- time curl -s http://reviews:9080/reviews/0
```{{exec}}

Now let's inject a delay to test timeout behavior:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-delay-timeout
spec:
  hosts:
  - reviews
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s  # Inject 5s delay
    route:
    - destination:
        host: reviews
        subset: v1
    timeout: 2s  # Timeout after 2s (less than delay)
EOF
```{{exec}}

Test the timeout:

```plain
kubectl exec -it $SLEEP_POD -- time curl -s http://reviews:9080/reviews/0
```{{exec}}

You should see the request timeout after 2 seconds instead of waiting 5 seconds.

## Configuring Retry Policies

### VirtualService Retry Configuration

Configure automatic retries for failed requests:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-retries
spec:
  hosts:
  - reviews
  http:
  - fault:
      abort:
        percentage:
          value: 50  # Fail 50% of requests
        httpStatus: 503
    route:
    - destination:
        host: reviews
        subset: v1
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure,refused-stream
EOF
```{{exec}}

### Test Retry Behavior

Test multiple times to see retry behavior:

```plain
for i in {1..5}; do
  echo "Request $i:"
  kubectl exec -it $SLEEP_POD -- curl -w "Response: %{http_code}, Time: %{time_total}s\n" -s http://reviews:9080/reviews/0 -o /dev/null
  echo
done
```{{exec}}

Some requests should succeed after retries despite the 50% failure rate.

## Advanced Retry Configuration

### Retry with Exponential Backoff

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-advanced-retries
spec:
  hosts:
  - reviews
  http:
  - fault:
      abort:
        percentage:
          value: 30
        httpStatus: 503
    route:
    - destination:
        host: reviews
        subset: v1
    retries:
      attempts: 4
      perTryTimeout: 2s
      retryOn: 5xx,gateway-error,connect-failure,refused-stream
      retryRemoteLocalities: true  # Retry on different zones
EOF
```{{exec}}

### DestinationRule-Level Connection Settings

Configure connection-level timeouts and retries:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-connection-settings
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
        connectTimeout: 5s
        keepAlive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 64
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
        maxRetries: 3
        consecutiveGatewayErrors: 3
        interval: 30s
        baseEjectionTime: 30s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF
```{{exec}}

## Testing Different Retry Conditions

### Test Connection-Level Retries

```plain
# Test with connection issues
kubectl exec -it $SLEEP_POD -- curl -w "Status: %{http_code}, Time: %{time_total}s\n" http://reviews:9080/reviews/0
```{{exec}}

### Monitor Retry Statistics

Check Envoy proxy statistics for retry information:

```plain
export SLEEP_POD_IP=$(kubectl get pod $SLEEP_POD -o jsonpath='{.status.podIP}')
kubectl exec -it $SLEEP_POD -c istio-proxy -- curl -s localhost:15000/stats | grep retry
```{{exec}}

```plain
kubectl exec -it $SLEEP_POD -c istio-proxy -- curl -s localhost:15000/stats | grep timeout
```{{exec}}

## Timeout and Retry Best Practices

### Appropriate Timeout Values

Configure timeouts based on service characteristics:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: service-specific-timeouts
spec:
  hosts:
  - reviews
  http:
  - match:
    - uri:
        prefix: /health
    route:
    - destination:
        host: reviews
        subset: v1
    timeout: 1s  # Fast timeout for health checks
  - match:
    - uri:
        prefix: /reviews
    route:
    - destination:
        host: reviews
        subset: v1
    timeout: 15s  # Longer timeout for business logic
    retries:
      attempts: 2
      perTryTimeout: 5s
EOF
```{{exec}}

## Observing Timeout and Retry Behavior

### Check Access Logs

```plain
kubectl logs $SLEEP_POD -c istio-proxy --tail=10 | grep -E "(timeout|retry)"
```{{exec}}

### View Envoy Configuration

```plain
istioctl proxy-config routes $SLEEP_POD --name 9080 -o json | grep -A 5 -B 5 -E "(timeout|retry)"
```{{exec}}

## Timeout and Retry Configuration Patterns

### Pattern 1: API Gateway Style
- **Short timeouts** for user-facing APIs (2-5s)
- **Limited retries** to prevent cascading delays (1-2 attempts)
- **Fast failure** for better user experience

### Pattern 2: Backend Service Style  
- **Longer timeouts** for internal services (10-30s)
- **More retries** for transient failures (3-5 attempts)
- **Exponential backoff** to prevent thundering herd

### Pattern 3: Critical Path Style
- **Conservative timeouts** to ensure reliability
- **Aggressive retries** with circuit breaker protection
- **Health-based routing** to avoid failed instances

## Clean Up Test Resources

```plain
kubectl delete virtualservice reviews-timeout reviews-delay-timeout reviews-retries reviews-advanced-retries service-specific-timeouts
```{{exec}}

```plain
kubectl delete destinationrule reviews-connection-settings
```{{exec}}

## Timeout and Retry Configuration Summary

| Configuration | VirtualService | DestinationRule |
|---------------|----------------|-----------------|
| Request Timeout | ✅ `timeout: 10s` | ❌ |  
| Per-Try Timeout | ✅ `perTryTimeout: 3s` | ❌ |
| Retry Attempts | ✅ `attempts: 3` | ❌ |
| Connection Timeout | ❌ | ✅ `connectTimeout: 5s` |
| Pool-Level Retries | ❌ | ✅ `maxRetries: 3` |

## Key Takeaways

1. **VirtualService** handles request-level timeouts and retries
2. **DestinationRule** handles connection-level timeouts  
3. **Combine both** for comprehensive resilience
4. **Test thoroughly** - retries can mask underlying issues
5. **Monitor metrics** to validate timeout/retry effectiveness
6. **Configure appropriately** - too aggressive can cause more problems

In the next step, we'll explore fault injection for testing these resilience features!