# Troubleshooting the Mesh Data Plane

The data plane consists of Envoy proxies (sidecars) that handle all traffic between services. Data plane issues often manifest as connectivity problems, traffic routing failures, or performance degradation.

## Data Plane Health Check

First, let's verify sidecar proxy health:

```plain
kubectl get pods -o wide
```{{exec}}

Check that all pods have 2 containers (app + istio-proxy):

```plain
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Sidecar Injection Issues

Let's check if sidecar injection is working properly:

```plain
kubectl get namespace -L istio-injection
```{{exec}}

```plain
kubectl describe pod $PRODUCTPAGE_POD | grep -A 10 -i "istio-proxy"
```{{exec}}

## Analyzing Sidecar Proxy Logs

Sidecar proxy logs are crucial for data plane troubleshooting:

```plain
kubectl logs $PRODUCTPAGE_POD -c istio-proxy --tail=20
```{{exec}}

Look for access logs and errors:

```plain
kubectl logs $PRODUCTPAGE_POD -c istio-proxy --tail=50 | grep -i error
```{{exec}}

## Envoy Proxy Configuration Inspection

Check the Envoy configuration that's actually loaded:

```plain
istioctl proxy-config listeners $PRODUCTPAGE_POD
```{{exec}}

```plain
istioctl proxy-config routes $PRODUCTPAGE_POD
```{{exec}}

```plain
istioctl proxy-config clusters $PRODUCTPAGE_POD
```{{exec}}

## Testing Connectivity Issues

Let's test connectivity between services:

```plain
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
echo $SLEEP_POD
```{{exec}}

Test basic connectivity:

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://productpage:9080
```{{exec}}

Test with detailed connection information:

```plain
kubectl exec -it $SLEEP_POD -- curl -v http://productpage:9080/productpage
```{{exec}}

## Debugging Traffic Routing

Let's check if traffic is being routed correctly:

```plain
istioctl proxy-config routes $PRODUCTPAGE_POD --name 9080
```{{exec}}

Check cluster endpoints:

```plain
istioctl proxy-config endpoints $PRODUCTPAGE_POD --cluster "outbound|9080||reviews.default.svc.cluster.local"
```{{exec}}

## Sidecar Proxy Performance Issues

Check proxy statistics:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep -E "(request|response|connection)"
```{{exec}}

Check proxy memory usage:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/memory
```{{exec}}

## Advanced Data Plane Debugging

### 1. Enable Debug Logging

Enable debug logging for specific components:

```plain
istioctl proxy-config log $PRODUCTPAGE_POD --level debug
```{{exec}}

Check the logs now:

```plain
kubectl logs $PRODUCTPAGE_POD -c istio-proxy --tail=10
```{{exec}}

Reset logging level:

```plain
istioctl proxy-config log $PRODUCTPAGE_POD --level warning
```{{exec}}

### 2. Envoy Admin Interface

Access Envoy's admin interface for detailed debugging:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/config_dump | head -50
```{{exec}}

Check listener details:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/listeners
```{{exec}}

### 3. Circuit Breaker Status

Check circuit breaker status:

```plain
kubectl exec -it $PRODUCTPAGE_POD -c istio-proxy -- curl -s localhost:15000/stats | grep circuit_breakers
```{{exec}}

## Common Data Plane Issues

### 1. Sidecar Injection Problems

```plain
# Check injection policy
kubectl get pod $PRODUCTPAGE_POD -o jsonpath='{.metadata.annotations.sidecar\.istio\.io/status}'
```{{exec}}

### 2. Proxy Configuration Sync Issues

```plain
# Check if proxy received latest config
istioctl proxy-status $PRODUCTPAGE_POD
```{{exec}}

### 3. Network Connectivity

Test network connectivity between sidecars:

```plain
kubectl exec -it $SLEEP_POD -c istio-proxy -- nc -zv productpage 9080
```{{exec}}

## Troubleshooting Network Policies

Check if network policies are blocking traffic:

```plain
kubectl get networkpolicy -A
```{{exec}}

Check PeerAuthentication and AuthorizationPolicy:

```plain
kubectl get peerauthentication,authorizationpolicy -A
```{{exec}}

## Load Balancing Issues

Check load balancing configuration:

```plain
istioctl proxy-config endpoints $SLEEP_POD --cluster "outbound|9080||reviews.default.svc.cluster.local"
```{{exec}}

## Data Plane Troubleshooting Workflow

When troubleshooting data plane issues:

1. ✅ **Verify sidecar injection** - Check containers and injection status
2. ✅ **Check proxy logs** - Look for errors and access patterns
3. ✅ **Inspect Envoy config** - Validate listeners, routes, clusters
4. ✅ **Test connectivity** - Use curl and network tools
5. ✅ **Check service discovery** - Verify endpoints are discovered
6. ✅ **Monitor proxy stats** - Check for circuit breakers, timeouts
7. ✅ **Validate security policies** - Review mTLS and authorization
8. ✅ **Check resource usage** - Monitor CPU and memory

In the next step, we'll cover advanced troubleshooting techniques for performance and certificates!