# Configuring Traffic Shifting and A/B Testing

In this step, you'll learn how to implement traffic shifting for canary deployments and A/B testing using weight-based routing and advanced matching conditions.

## Understanding Traffic Shifting

Traffic shifting enables:
- **Canary deployments**: Gradual rollout of new versions
- **A/B testing**: Compare different versions with real traffic
- **Blue-green deployments**: Switch between environments
- **Feature flags**: Route based on user characteristics
- **Risk mitigation**: Gradually increase traffic to new versions

## Apply Traffic Shifting Configuration

Deploy the traffic shifting configuration:

```bash
kubectl apply -f /tmp/traffic-shifting.yaml
```{{exec}}

View the traffic shifting setup:

```bash
kubectl get virtualservice reviews-traffic-shifting -o yaml
```{{exec}}

## Implement Canary Deployment

Start with 90% traffic to v1 and 10% to v2:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-canary
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
EOF
```{{exec}}

## Test Traffic Distribution

Generate traffic to test the distribution:

```bash
# Generate 100 requests and count responses
for i in {1..100}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -q "glyphicon-star" && echo "v2" || echo "v1"
done | sort | uniq -c
```{{exec}}

## Gradual Traffic Shift

Gradually increase traffic to v2 (50-50 split):

```bash
kubectl patch virtualservice reviews-canary --type='merge' -p='{"spec":{"http":[{"route":[{"destination":{"host":"reviews","subset":"v1"},"weight":50},{"destination":{"host":"reviews","subset":"v2"},"weight":50}]}]}}'
```{{exec}}

Test the new distribution:

```bash
for i in {1..50}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -q "glyphicon-star" && echo "v2" || echo "v1"
done | sort | uniq -c
```{{exec}}

## Complete the Canary Rollout

Move 100% traffic to v2:

```bash
kubectl patch virtualservice reviews-canary --type='merge' -p='{"spec":{"http":[{"route":[{"destination":{"host":"reviews","subset":"v2"},"weight":100}]}]}}'
```{{exec}}

## Implement A/B Testing

Create A/B test based on user characteristics:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-ab-test
spec:
  hosts:
  - reviews
  http:
  # Route mobile users to v3 (red stars)
  - match:
    - headers:
        user-agent:
          regex: ".*Mobile.*|.*Android.*|.*iPhone.*"
    route:
    - destination:
        host: reviews
        subset: v3
  # Route premium users to v2 (black stars)
  - match:
    - headers:
        user-tier:
          exact: "premium"
    route:
    - destination:
        host: reviews
        subset: v2
  # Route beta users to v3
  - match:
    - headers:
        user-group:
          exact: "beta"
    route:
    - destination:
        host: reviews
        subset: v3
  # Default routing for remaining users
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 80
    - destination:
        host: reviews
        subset: v2
      weight: 20
EOF
```{{exec}}

## Test A/B Configuration

Test different user categories:

```bash
# Test mobile user
curl -s "http://$GATEWAY_URL/productpage" -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)" | grep -A 5 "reviews"

# Test premium user
curl -s "http://$GATEWAY_URL/productpage" -H "user-tier: premium" | grep -A 5 "reviews"

# Test beta user
curl -s "http://$GATEWAY_URL/productpage" -H "user-group: beta" | grep -A 5 "reviews"

# Test regular user
curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 "reviews"
```{{exec}}

## Implement Feature Flags

Create feature flag routing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-feature-flags
spec:
  hosts:
  - reviews
  http:
  # Feature flag: new-ui enabled
  - match:
    - headers:
        x-feature-new-ui:
          exact: "enabled"
    route:
    - destination:
        host: reviews
        subset: v3
  # Feature flag: enhanced-ratings enabled  
  - match:
    - headers:
        x-feature-enhanced-ratings:
          exact: "enabled"
    route:
    - destination:
        host: reviews
        subset: v2
  # Geographic routing
  - match:
    - headers:
        x-user-region:
          exact: "us-west"
    route:
    - destination:
        host: reviews
        subset: v2
      weight: 70
    - destination:
        host: reviews
        subset: v1
      weight: 30
  # Default routing
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```{{exec}}

## Test Feature Flags

Test feature flag behavior:

```bash
# Test new-ui feature
curl -s "http://$GATEWAY_URL/productpage" -H "x-feature-new-ui: enabled" | grep -A 5 "reviews"

# Test enhanced-ratings feature
curl -s "http://$GATEWAY_URL/productpage" -H "x-feature-enhanced-ratings: enabled" | grep -A 5 "reviews"

# Test geographic routing
curl -s "http://$GATEWAY_URL/productpage" -H "x-user-region: us-west" | grep -A 5 "reviews"
```{{exec}}

## Monitor Traffic Metrics

Check traffic distribution metrics:

```bash
# View proxy stats for traffic distribution
istioctl proxy-config cluster $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') --fqdn reviews.default.svc.cluster.local -o json | jq '.[] | {name: .name, hosts: .loadAssignment.endpoints[].lbEndpoints[].endpoint.address}'
```{{exec}}

## Advanced Traffic Shaping

Implement complex traffic shaping with multiple conditions:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-advanced-shaping
spec:
  hosts:
  - reviews
  http:
  # Morning traffic (8 AM - 12 PM) - more capacity
  - match:
    - headers:
        x-time-of-day:
          regex: "0[8-9]|1[0-2]"
    route:
    - destination:
        host: reviews
        subset: v2
      weight: 60
    - destination:
        host: reviews
        subset: v1
      weight: 40
  # Evening traffic (6 PM - 10 PM) - premium experience
  - match:
    - headers:
        x-time-of-day:
          regex: "1[8-9]|2[0-2]"
    route:
    - destination:
        host: reviews
        subset: v3
      weight: 80
    - destination:
        host: reviews
        subset: v2
      weight: 20
  # Weekend traffic - experimental features
  - match:
    - headers:
        x-day-of-week:
          regex: "Saturday|Sunday"
    route:
    - destination:
        host: reviews
        subset: v3
      weight: 50
    - destination:
        host: reviews
        subset: v2
      weight: 30
    - destination:
        host: reviews
        subset: v1
      weight: 20
  # Default traffic distribution
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 70
    - destination:
        host: reviews
        subset: v2
      weight: 30
EOF
```{{exec}}

## Rollback Strategy

Implement quick rollback capability:

```bash
# Emergency rollback to v1
kubectl patch virtualservice reviews-advanced-shaping --type='merge' -p='{"spec":{"http":[{"route":[{"destination":{"host":"reviews","subset":"v1"},"weight":100}]}]}}'

# Verify rollback
curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 "reviews"
```{{exec}}

## Key Takeaways

- Traffic shifting enables safe canary deployments
- Weight-based routing supports gradual rollouts
- A/B testing uses header matching for user segmentation
- Feature flags provide fine-grained traffic control
- Multiple conditions enable sophisticated traffic shaping
- Quick rollback strategies are essential for production

In the next step, you'll learn about connecting mesh workloads to external services.