# Using Fault Injection for Chaos Engineering and Testing

In this step, you'll learn how to use Istio's fault injection capabilities to test system resilience through controlled failure simulation, enabling chaos engineering practices and comprehensive testing strategies.

## Understanding Fault Injection

Fault injection enables:
- **Delay injection**: Simulate network latency and slow services  
- **Abort injection**: Simulate service failures and error conditions
- **HTTP error codes**: Test different failure scenarios
- **Percentage-based faults**: Control fault occurrence rates
- **Header-based targeting**: Apply faults to specific user segments
- **Chaos engineering**: Proactive resilience testing

## Apply Fault Injection Configuration

Deploy the fault injection configuration:

```bash
kubectl apply -f /tmp/fault-injection.yaml
```{{exec}}

View the fault injection setup:

```bash
kubectl get virtualservice fault-injection -o yaml
```{{exec}}

## Configure Delay Injection

Create delay injection for testing timeout behavior:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-delay-injection
spec:
  hosts:
  - reviews
  http:
  # Inject 5 second delay for 50% of requests
  - match:
    - headers:
        end-user:
          exact: jason
    fault:
      delay:
        percentage:
          value: 50.0
        fixedDelay: 5s
    route:
    - destination:
        host: reviews
        subset: v2
  # Normal routing for other users
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```{{exec}}

## Test Delay Injection

Test the delay injection:

```bash
# Test with jason user (should have delays)
for i in {1..5}; do
  echo "Request $i (jason):"
  time curl -s "http://$GATEWAY_URL/productpage" -H "end-user: jason" > /dev/null
done

# Test with anonymous user (should be fast)
for i in {1..3}; do
  echo "Request $i (anonymous):"
  time curl -s "http://$GATEWAY_URL/productpage" > /dev/null
done
```{{exec}}

## Configure Abort Injection

Create abort injection for testing error handling:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings-abort-injection
spec:
  hosts:
  - ratings
  http:
  # Inject HTTP 503 errors for 30% of requests for specific user
  - match:
    - headers:
        end-user:
          exact: alice
    fault:
      abort:
        percentage:
          value: 30.0
        httpStatus: 503
    route:
    - destination:
        host: ratings
        subset: v1
  # Normal routing for other requests
  - route:
    - destination:
        host: ratings
        subset: v1
EOF
```{{exec}}

## Test Abort Injection

Test abort injection behavior:

```bash
# Test with alice user (should see errors)
for i in {1..10}; do
  echo "Request $i (alice):"
  curl -s "http://$GATEWAY_URL/productpage" -H "end-user: alice" | grep -q "error" && echo "ERROR" || echo "SUCCESS"
done
```{{exec}}

## Configure Combined Fault Injection

Create sophisticated fault injection with multiple conditions:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-combined-faults
spec:
  hosts:
  - httpbin
  http:
  # Mobile users: 20% delay + 10% abort
  - match:
    - headers:
        user-agent:
          regex: ".*Mobile.*"
    fault:
      delay:
        percentage:
          value: 20.0
        fixedDelay: 3s
      abort:
        percentage:
          value: 10.0
        httpStatus: 500
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Beta users: High error rate for testing
  - match:
    - headers:
        x-user-group:
          exact: "beta"
    fault:
      abort:
        percentage:
          value: 40.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Test environment: Random failures
  - match:
    - headers:
        x-environment:
          exact: "test"
    fault:
      delay:
        percentage:
          value: 30.0
        fixedDelay: 2s
      abort:
        percentage:
          value: 15.0
        httpStatus: 502
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Production: Low fault rate
  - match:
    - headers:
        x-environment:
          exact: "prod"
    fault:
      delay:
        percentage:
          value: 2.0
        fixedDelay: 1s
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Default routing
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test Combined Fault Scenarios

Test different fault combinations:

```bash
# Test mobile user faults
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" -H "User-Agent: Mobile Safari" http://httpbin:8000/get; done

# Test beta user faults
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Status: %{http_code}\n" -H "x-user-group: beta" http://httpbin:8000/get; done

# Test environment-specific faults
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" -H "x-environment: test" http://httpbin:8000/get; done
```{{exec}}

## Configure Time-Based Fault Injection

Create fault injection based on time conditions:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: time-based-faults
spec:
  hosts:
  - httpbin
  http:
  # Peak hours: Higher fault rate to test scalability
  - match:
    - headers:
        x-time-of-day:
          regex: "0[9-1][0-7]"  # 9 AM to 5 PM
    fault:
      delay:
        percentage:
          value: 15.0
        fixedDelay: 2s
      abort:
        percentage:
          value: 8.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Off hours: Maintenance simulation
  - match:
    - headers:
        x-time-of-day:
          regex: "0[0-5]"  # Midnight to 5 AM
    fault:
      abort:
        percentage:
          value: 25.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Weekend: Partial outage simulation
  - match:
    - headers:
        x-day-of-week:
          regex: "Saturday|Sunday"
    fault:
      delay:
        percentage:
          value: 40.0
        fixedDelay: 4s
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Configure Geographic Fault Injection

Create region-specific fault injection:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: geo-faults
spec:
  hosts:
  - httpbin
  http:
  # US East: Simulate regional outage
  - match:
    - headers:
        x-user-region:
          exact: "us-east"
    fault:
      abort:
        percentage:
          value: 60.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Europe: Network latency simulation
  - match:
    - headers:
        x-user-region:
          exact: "eu-west"
    fault:
      delay:
        percentage:
          value: 80.0
        fixedDelay: 300ms
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Asia Pacific: Mixed issues
  - match:
    - headers:
        x-user-region:
          exact: "ap-southeast"
    fault:
      delay:
        percentage:
          value: 20.0
        fixedDelay: 1s
      abort:
        percentage:
          value: 5.0
        httpStatus: 502
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test Geographic Faults

Test regional fault behavior:

```bash
# Test US East outage
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Status: %{http_code}\n" -H "x-user-region: us-east" http://httpbin:8000/get; done | sort | uniq -c

# Test EU latency
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Time: %{time_total}s\n" -H "x-user-region: eu-west" http://httpbin:8000/get; done

# Test AP mixed issues
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..10}; do curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" -H "x-user-region: ap-southeast" http://httpbin:8000/get; done
```{{exec}}

## Create Chaos Engineering Scenarios

Implement comprehensive chaos testing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: chaos-engineering
spec:
  hosts:
  - reviews
  - ratings
  - details
  http:
  # Cascade failure simulation
  - match:
    - headers:
        x-chaos-scenario:
          exact: "cascade-failure"
    fault:
      abort:
        percentage:
          value: 100.0
        httpStatus: 503
    route:
    - destination:
        host: ratings
        subset: v1
  # Slow dependency simulation
  - match:
    - headers:
        x-chaos-scenario:
          exact: "slow-dependency"
    fault:
      delay:
        percentage:
          value: 100.0
        fixedDelay: 10s
    route:
    - destination:
        host: details
        subset: v1
  # Intermittent failure
  - match:
    - headers:
        x-chaos-scenario:
          exact: "intermittent-failure"
    fault:
      abort:
        percentage:
          value: 50.0
        httpStatus: 502
    route:
    - destination:
        host: reviews
        subset: v2
  # Normal routing
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 33
    - destination:
        host: ratings
        subset: v1
      weight: 33
    - destination:
        host: details
        subset: v1
      weight: 34
EOF
```{{exec}}

## Execute Chaos Engineering Tests

Run chaos engineering scenarios:

```bash
# Test cascade failure
echo "Testing cascade failure:"
for i in {1..5}; do
  curl -s "http://$GATEWAY_URL/productpage" -H "x-chaos-scenario: cascade-failure" | grep -q "ratings" && echo "FAIL" || echo "HANDLED"
done

# Test slow dependency
echo "Testing slow dependency:"
time curl -s "http://$GATEWAY_URL/productpage" -H "x-chaos-scenario: slow-dependency" > /dev/null

# Test intermittent failure
echo "Testing intermittent failure:"
for i in {1..10}; do
  curl -s "http://$GATEWAY_URL/productpage" -H "x-chaos-scenario: intermittent-failure" | grep -q "error" && echo "ERROR" || echo "SUCCESS"
done | sort | uniq -c
```{{exec}}

## Monitor Fault Injection Impact

Check fault injection metrics and effects:

```bash
# View fault injection statistics
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep fault

# Check upstream request statistics with faults
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep -E "(upstream_rq_.*|fault_.*)" | grep httpbin

# Monitor response codes
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep -E "upstream_rq_[0-9]xx" | grep httpbin
```{{exec}}

## Configure Gradual Fault Injection

Implement gradual fault increase for testing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: gradual-fault-increase
spec:
  hosts:
  - httpbin
  http:
  # Phase 1: Low fault rate (5%)
  - match:
    - headers:
        x-fault-phase:
          exact: "1"
    fault:
      abort:
        percentage:
          value: 5.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Phase 2: Medium fault rate (25%)
  - match:
    - headers:
        x-fault-phase:
          exact: "2"
    fault:
      abort:
        percentage:
          value: 25.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  # Phase 3: High fault rate (50%)
  - match:
    - headers:
        x-fault-phase:
          exact: "3"
    fault:
      abort:
        percentage:
          value: 50.0
        httpStatus: 503
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test Gradual Fault Increase

Test gradual fault escalation:

```bash
# Phase 1: 5% failure rate
echo "Phase 1 (5% failures):"
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..20}; do curl -s -w "%{http_code}\n" -H "x-fault-phase: 1" http://httpbin:8000/get; done | sort | uniq -c

# Phase 2: 25% failure rate  
echo "Phase 2 (25% failures):"
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..20}; do curl -s -w "%{http_code}\n" -H "x-fault-phase: 2" http://httpbin:8000/get; done | sort | uniq -c

# Phase 3: 50% failure rate
echo "Phase 3 (50% failures):"
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- for i in {1..20}; do curl -s -w "%{http_code}\n" -H "x-fault-phase: 3" http://httpbin:8000/get; done | sort | uniq -c
```{{exec}}

## Clean Up Fault Injection

Remove fault injection for normal operation:

```bash
# Remove all fault injection rules
kubectl delete virtualservice reviews-delay-injection ratings-abort-injection httpbin-combined-faults time-based-faults geo-faults chaos-engineering gradual-fault-increase --ignore-not-found=true

# Verify removal
kubectl get virtualservice
```{{exec}}

## Key Takeaways

- Fault injection enables proactive resilience testing
- Delay injection tests timeout and retry behavior  
- Abort injection validates error handling paths
- Percentage-based faults control failure rates
- Header-based targeting enables specific test scenarios
- Chaos engineering improves system reliability
- Gradual fault injection validates system limits
- Always monitor fault injection impact on system performance

Congratulations! You have completed Domain 2: Traffic Management. You've learned comprehensive traffic management including gateways, routing, policies, shifting, external services, resilience features, timeouts/retries, and fault injection.