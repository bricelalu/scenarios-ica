# Configuring Authorization with AuthorizationPolicy

In this step, you'll learn how to configure fine-grained authorization policies using Istio's AuthorizationPolicy resource to control access to services based on various attributes like source, destination, and request properties.

## Understanding Authorization Policies

AuthorizationPolicy features:
- **Namespace-scoped**: Policies apply to workloads in the same namespace
- **Selector-based**: Target specific workloads using labels
- **ALLOW/DENY actions**: Explicitly allow or deny requests
- **Rich matching**: Source, destination, method, path, headers
- **Default deny**: When no policy matches, access is allowed (permissive mode)

## Install Istio and Deploy Applications

Install Istio with security features:

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
cd istio-1.26.0
export PATH=$PWD/bin:$PATH
istioctl install --set values.pilot.env.PILOT_ENABLE_AUTHORIZATION_POLICY=true -y
kubectl label namespace default istio-injection=enabled
```{{exec}}

Deploy test applications:

```bash
kubectl apply -f /tmp/bookinfo.yaml
kubectl apply -f /tmp/httpbin.yaml
kubectl apply -f /tmp/sleep-pod.yaml
```{{exec}}

Wait for all pods to be ready:

```bash
kubectl wait --for=condition=ready pod --all --timeout=300s
```{{exec}}

## Test Default Behavior (Permissive Mode)

Test that all services are accessible by default:

```bash
# Test productpage access
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://productpage:9080/productpage | grep -o "<title>.*</title>"

# Test direct service access
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1

# Test httpbin access
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/ip
```{{exec}}

## Apply Deny-All Policy

Create a deny-all policy to implement default-deny security model:

```bash
kubectl apply -f /tmp/authorization-deny-all.yaml
```{{exec}}

View the policy:

```bash
kubectl get authorizationpolicy deny-all -o yaml
```{{exec}}

## Test Denied Access

Test that access is now denied:

```bash
# These should all fail with RBAC: access denied
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://productpage:9080/productpage || echo "Access denied as expected"

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1 || echo "Access denied as expected"

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/ip || echo "Access denied as expected"
```{{exec}}

## Create Selective Allow Policies

Apply policies to allow specific access:

```bash
kubectl apply -f /tmp/authorization-allow-get.yaml
```{{exec}}

View the allow policy:

```bash
kubectl get authorizationpolicy productpage-viewer -o yaml
```{{exec}}

## Test Allowed Access

Test that GET requests are now allowed:

```bash
# GET requests should work
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://productpage:9080/productpage | grep -o "<title>.*</title>"

# POST requests should still be denied
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST http://productpage:9080/productpage || echo "POST access denied as expected"
```{{exec}}

## Configure Source-Based Authorization

Create authorization based on source workload:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-source-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
EOF
```{{exec}}

## Test Source-Based Authorization

Test access from different sources:

```bash
# Access from productpage pod (should work)
kubectl exec -it $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1

# Access from sleep pod (should fail)
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://reviews:9080/reviews/1 || echo "Access denied from sleep pod as expected"
```{{exec}}

## Configure Path-Based Authorization

Create authorization based on request paths:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-path-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - to:
    - operation:
        paths: ["/get", "/status/*", "/headers"]
        methods: ["GET"]
  - to:
    - operation:
        paths: ["/post"]
        methods: ["POST"]
EOF
```{{exec}}

## Test Path-Based Authorization

Test access to different paths:

```bash
# Allowed paths
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/get | jq '.url'

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/status/200

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST -d '{"test":"data"}' http://httpbin:8000/post | jq '.json'

# Denied paths
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/put || echo "Access to /put denied as expected"

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/delete || echo "Access to /delete denied as expected"
```{{exec}}

## Configure Header-Based Authorization

Create authorization based on HTTP headers:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-header-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  # Allow admin users full access
  - when:
    - key: request.headers[x-user-role]
      values: ["admin"]
  # Allow regular users limited access
  - when:
    - key: request.headers[x-user-role]
      values: ["user"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get", "/status/*"]
  # Allow anonymous access to status only
  - to:
    - operation:
        methods: ["GET"]
        paths: ["/status/200"]
EOF
```{{exec}}

## Test Header-Based Authorization

Test access with different headers:

```bash
# Admin access (should work for everything)
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: admin" http://httpbin:8000/get | jq '.headers["X-User-Role"]'

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: admin" -X POST -d '{"test":"admin"}' http://httpbin:8000/post | jq '.json'

# User access (limited)
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: user" http://httpbin:8000/get | jq '.headers["X-User-Role"]'

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: user" -X POST http://httpbin:8000/post || echo "POST denied for user role as expected"

# Anonymous access (very limited)
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/status/200

kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/get || echo "Anonymous access to /get denied as expected"
```{{exec}}

## Configure IP-Based Authorization

Create authorization based on source IP:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ratings-ip-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  action: ALLOW
  rules:
  - from:
    - source:
        remoteIpBlocks: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  - when:
    - key: source.ip
      values: ["127.0.0.1"]
EOF
```{{exec}}

## Apply Complex RBAC Policy

Deploy complex authorization with multiple conditions:

```bash
kubectl apply -f /tmp/authorization-rbac-complex.yaml
```{{exec}}

View the complex policy:

```bash
kubectl get authorizationpolicy details-complex-rbac -o yaml
```{{exec}}

## Create Deny Policy

Create an explicit DENY policy:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-deny-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: DENY
  rules:
  - when:
    - key: request.headers[x-user-type]
      values: ["blocked", "suspicious"]
  - to:
    - operation:
        methods: ["DELETE", "PUT"]
EOF
```{{exec}}

## Test Deny Policy

Test that deny policies take precedence:

```bash
# Blocked user should be denied even with admin role
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: admin" -H "x-user-type: blocked" http://httpbin:8000/get || echo "Blocked user denied as expected"

# DELETE method should be denied for everyone
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: admin" -X DELETE http://httpbin:8000/delete || echo "DELETE method denied as expected"

# Normal admin should still work for allowed operations
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-user-role: admin" http://httpbin:8000/get | jq '.headers["X-User-Role"]'
```{{exec}}

## Monitor Authorization Policies

Check policy status and debug authorization:

```bash
# List all authorization policies
kubectl get authorizationpolicy

# Check proxy configuration
istioctl proxy-config rbac $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}')

# Analyze configuration
istioctl analyze
```{{exec}}

## Debug Authorization Issues

Use istioctl to troubleshoot authorization:

```bash
# Check authorization policy configuration
kubectl describe authorizationpolicy

# View effective RBAC configuration
istioctl proxy-config rbac $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -o json | jq '.[0].policies'
```{{exec}}

## Clean Up Specific Policies

Remove the deny-all policy to restore normal access:

```bash
kubectl delete authorizationpolicy deny-all
```{{exec}}

Test that access is restored:

```bash
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://productpage:9080/productpage | grep -o "<title>.*</title>"
```{{exec}}

## Key Takeaways

- AuthorizationPolicy provides fine-grained access control
- Default behavior is ALLOW (permissive mode)
- DENY policies take precedence over ALLOW policies
- Policies support source, destination, and request attribute matching
- Header-based authorization enables user role enforcement
- Path-based authorization restricts access to specific endpoints
- Always test policies thoroughly before production deployment

In the next step, you'll learn about mTLS authentication with PeerAuthentication.