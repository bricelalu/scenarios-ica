# Advanced Troubleshooting - Performance, Certificates, and Service Discovery

In this step, we'll cover advanced troubleshooting techniques for complex issues that often appear in production environments and ICA exams.

## Performance Troubleshooting

### Analyzing Request Latency

Let's check request performance and identify bottlenecks:

```plain
# Generate some load to analyze
for i in {1..10}; do
  kubectl exec -it $SLEEP_POD -- curl -w "Time: %{time_total}s\n" -s http://productpage:9080/productpage -o /dev/null
done
```{{exec}}

Check Envoy proxy statistics for performance metrics:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep -E "(request_time|response_time|upstream_rq_time)"
```{{exec}}

### Circuit Breaker Analysis

Check circuit breaker statistics:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep circuit_breakers
```{{exec}}

### Connection Pool Analysis

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep -E "(cx_|rq_pending|rq_retry)"
```{{exec}}

### Memory and CPU Usage

```plain
kubectl top pods
```{{exec}}

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/memory
```{{exec}}

## Certificate Troubleshooting

Certificate issues are common in mTLS environments. Let's master certificate debugging:

### Check Certificate Status

```plain
istioctl authn tls-check $PRODUCTPAGE_POD reviews.default.svc.cluster.local
```{{exec}}

### Inspect Certificate Details

```plain
istioctl proxy-config secret $PRODUCTPAGE_POD
```{{exec}}

### Verify Root Certificate

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- openssl s_client -connect reviews:9080 -showcerts < /dev/null
```{{exec}}

### Certificate Rotation Issues

Check certificate expiration:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/certs | grep -A 5 -B 5 "expire"
```{{exec}}

### mTLS Connectivity Testing

Test mTLS connectivity between services:

```plain
kubectl exec -it $SLEEP_POD -- openssl s_client -connect productpage:9080 -cert /etc/ssl/certs/cert-chain.pem -key /etc/ssl/private/key.pem -CAfile /etc/ssl/certs/root-cert.pem
```{{exec}}

## Service Discovery Troubleshooting

Service discovery issues can cause mysterious connectivity problems:

### Check Service Registration

```plain
kubectl get services
```{{exec}}

```plain
kubectl get endpoints
```{{exec}}

### Verify Service Discovery in Envoy

```plain
istioctl proxy-config endpoints $PRODUCTPAGE_POD
```{{exec}}

### Check DNS Resolution

```plain
kubectl exec -it $SLEEP_POD -- nslookup productpage.default.svc.cluster.local
```{{exec}}

```plain
kubectl exec -it $SLEEP_POD -- nslookup reviews.default.svc.cluster.local
```{{exec}}

### Analyze Service Mesh Service Registry

```plain
istioctl proxy-config endpoints $PRODUCTPAGE_POD --cluster "outbound|9080||reviews.default.svc.cluster.local"
```{{exec}}

## Advanced Diagnostic Techniques

### Using istioctl describe

The `describe` command provides comprehensive analysis:

```plain
istioctl describe pod $PRODUCTPAGE_POD
```{{exec}}

### Analyzing Traffic Flow

```plain
istioctl analyze --all-namespaces
```{{exec}}

### Check Pilot Debug Information

```plain
kubectl port-forward -n istio-system svc/istiod 15014:15014 &
```{{exec}}

```plain
curl -s localhost:15014/debug/endpointz | head -20
```{{exec}}

Stop port forwarding:
```plain
pkill -f "port-forward.*15014"
```{{exec}}

## Troubleshooting Cross-Cluster Issues

Even in single-cluster scenarios, understanding cross-cluster debugging is valuable:

### Network Endpoint Analysis

```plain
kubectl get workloadentry -A
```{{exec}}

### Gateway Connectivity

```plain
kubectl get gateway -A
```{{exec}}

```plain
istioctl proxy-config listeners -n istio-system istio-ingressgateway-<TAB>
```{{exec}}

Let's get the actual gateway pod:

```plain
export GATEWAY_POD=$(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}')
echo $GATEWAY_POD
```{{exec}}

```plain
istioctl proxy-config listeners -n istio-system $GATEWAY_POD
```{{exec}}

## Performance Optimization Troubleshooting

### Resource Limits Analysis

```plain
kubectl describe pod $PRODUCTPAGE_POD | grep -A 10 -B 5 -i limits
```{{exec}}

### Envoy Performance Tuning

Check current Envoy configuration:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep server
```{{exec}}

### Thread and Connection Analysis

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep -E "(worker_|thread_)"
```{{exec}}

## Troubleshooting Checklist for Advanced Issues

### 🔍 Performance Issues:
1. ✅ Check request latency metrics
2. ✅ Analyze circuit breaker statistics  
3. ✅ Monitor connection pool usage
4. ✅ Review resource limits and usage
5. ✅ Inspect Envoy performance stats

### 🔒 Certificate Issues:
1. ✅ Verify mTLS status with tls-check
2. ✅ Inspect certificate details and expiration
3. ✅ Test certificate chain validation
4. ✅ Check root certificate distribution
5. ✅ Validate certificate rotation

### 🌐 Service Discovery Issues:
1. ✅ Verify service and endpoint registration
2. ✅ Check DNS resolution
3. ✅ Analyze Envoy endpoint configuration
4. ✅ Validate service mesh registry
5. ✅ Test cross-cluster connectivity

## Advanced Debugging Commands Reference

```bash
# Performance Analysis
kubectl exec -it $POD -c istio-proxy -- curl -s localhost:15000/stats | grep -E "(time|latency|duration)"

# Certificate Inspection  
istioctl proxy-config secret $POD -o json

# Service Discovery Debug
istioctl proxy-config endpoints $POD --cluster $CLUSTER_NAME

# Configuration Dump
kubectl exec -it $POD -c istio-proxy -- curl -s localhost:15000/config_dump > config.json

# Memory Analysis
kubectl exec -it $POD -c istio-proxy -- curl -s localhost:15000/memory
```

In the final troubleshooting step, we'll focus on security policy debugging!