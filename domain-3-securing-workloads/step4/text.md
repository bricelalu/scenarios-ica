# Advanced Authorization Patterns

Authorization in Istio goes far beyond simple ALLOW/DENY rules. This step covers complex authorization patterns that appear frequently in ICA exams and production environments, including namespace-based authorization, source identity verification, and sophisticated RBAC patterns.

## Understanding Advanced Authorization Concepts

**Authorization layers in Istio:**
1. **Namespace-level** - Control cross-namespace access
2. **Service Account-based** - Identity-driven authorization
3. **Source-based** - Control based on request origin
4. **Operation-based** - Method and path-specific rules
5. **Header-based** - Custom header authorization
6. **Time-based** - Conditional access patterns

## Setting Up Multi-Namespace Environment

Let's create multiple namespaces to demonstrate advanced patterns:

```plain
kubectl create namespace production
kubectl create namespace staging  
kubectl create namespace external
```{{exec}}

Label namespaces for injection:

```plain
kubectl label namespace production istio-injection=enabled
kubectl label namespace staging istio-injection=enabled
kubectl label namespace external istio-injection=enabled
```{{exec}}

Deploy services across namespaces:

```plain
# Deploy httpbin in production
kubectl apply -n production -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
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
      serviceAccountName: httpbin
      containers:
      - image: kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
    service: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin
EOF
```{{exec}}

```plain
# Deploy sleep in staging
kubectl apply -n staging -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      serviceAccountName: sleep
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
        imagePullPolicy: IfNotPresent
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sleep
EOF
```{{exec}}

Wait for deployments:

```plain
kubectl wait --for=condition=Ready pods -n production -l app=httpbin --timeout=120s
kubectl wait --for=condition=Ready pods -n staging -l app=sleep --timeout=120s
```{{exec}}

## Namespace-Based Authorization

### Block Cross-Namespace Access by Default

Create a default-deny policy for the production namespace:

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: default-deny-production
  namespace: production
spec:
  # No rules = deny all access
EOF
```{{exec}}

Test that access is blocked:

```plain
export STAGING_SLEEP=$(kubectl get pod -n staging -l app=sleep -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/headers
```{{exec}}

### Allow Specific Namespace Access

Allow only staging namespace to access production services:

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-staging-to-production
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        namespaces: ["staging"]
    to:
    - operation:
        methods: ["GET", "POST"]
EOF
```{{exec}}

Test that staging can now access production:

```plain
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/headers
```{{exec}}

## Service Account-Based Authorization

### Create Service Accounts with Different Roles

```plain
# Create admin service account
kubectl apply -n staging -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  labels:
    role: admin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin-client
  template:
    metadata:
      labels:
        app: admin-client
    spec:
      serviceAccountName: admin
      containers:
      - name: admin-client
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
        imagePullPolicy: IfNotPresent
EOF
```{{exec}}

Wait for admin client:

```plain
kubectl wait --for=condition=Ready pods -n staging -l app=admin-client --timeout=120s
```{{exec}}

### Configure Service Account-Based Authorization

Allow only admin service accounts to perform DELETE operations:

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: admin-only-delete
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/staging/sa/sleep"]
    to:
    - operation:
        methods: ["GET"]
  - from:
    - source:
        principals: ["cluster.local/ns/staging/sa/admin"]
    to:
    - operation:
        methods: ["GET", "POST", "DELETE"]
EOF
```{{exec}}

Test with regular service account (should fail DELETE):

```plain
kubectl exec -n staging -it $STAGING_SLEEP -- curl -X DELETE -I http://httpbin.production.svc.cluster.local:8000/delete
```{{exec}}

Test with admin service account:

```plain
export ADMIN_POD=$(kubectl get pod -n staging -l app=admin-client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n staging -it $ADMIN_POD -- curl -X DELETE -I http://httpbin.production.svc.cluster.local:8000/delete
```{{exec}}

## Header-Based Authorization

### Implement Role-Based Header Authorization

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: role-based-headers
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        namespaces: ["staging"]
    when:
    - key: request.headers[user-role]
      values: ["admin", "operator"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
  - from:
    - source:
        namespaces: ["staging"]
    when:
    - key: request.headers[user-role]  
      values: ["user"]
    to:
    - operation:
        methods: ["GET"]
EOF
```{{exec}}

Test with different roles:

```plain
# Test as user (should only allow GET)
kubectl exec -n staging -it $STAGING_SLEEP -- curl -H "user-role: user" -I http://httpbin.production.svc.cluster.local:8000/headers
kubectl exec -n staging -it $STAGING_SLEEP -- curl -H "user-role: user" -X POST -I http://httpbin.production.svc.cluster.local:8000/post
```{{exec}}

```plain
# Test as admin (should allow all methods)
kubectl exec -n staging -it $STAGING_SLEEP -- curl -H "user-role: admin" -X POST -I http://httpbin.production.svc.cluster.local:8000/post
kubectl exec -n staging -it $STAGING_SLEEP -- curl -H "user-role: admin" -X DELETE -I http://httpbin.production.svc.cluster.local:8000/delete
```{{exec}}

## Path-Based Authorization

### Implement Granular Path Controls

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: path-based-access
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        namespaces: ["staging"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/headers", "/status/*", "/get"]
  - from:
    - source:
        principals: ["cluster.local/ns/staging/sa/admin"]
    to:
    - operation:
        methods: ["GET", "POST", "DELETE"]
        paths: ["/delete", "/post", "/put"]
EOF
```{{exec}}

Test path-based access:

```plain
# Regular user access to allowed paths
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/headers
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/status/200
```{{exec}}

```plain
# Regular user access to restricted paths (should fail)
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/delete
```{{exec}}

```plain
# Admin access to restricted paths (should work)
kubectl exec -n staging -it $ADMIN_POD -- curl -X DELETE -I http://httpbin.production.svc.cluster.local:8000/delete
```{{exec}}

## Complex Multi-Condition Authorization

### Combine Multiple Authorization Criteria

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: complex-authorization
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  # Rule 1: Admin users can do anything from staging
  - from:
    - source:
        namespaces: ["staging"]
        principals: ["cluster.local/ns/staging/sa/admin"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
  # Rule 2: Regular users from staging can only GET specific paths with valid role header
  - from:
    - source:
        namespaces: ["staging"]
        principals: ["cluster.local/ns/staging/sa/sleep"]
    when:
    - key: request.headers[user-role]
      values: ["user", "viewer"]
    - key: request.headers[x-request-id]
      notValues: [""]  # Must have request ID
    to:
    - operation:
        methods: ["GET"]
        paths: ["/headers", "/status/*", "/get", "/ip"]
  # Rule 3: Allow health checks from any namespace
  - from:
    - source:
        namespaces: ["staging", "default", "kube-system"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/status/200"]
EOF
```{{exec}}

Test complex authorization:

```plain
# Test regular user with proper headers
kubectl exec -n staging -it $STAGING_SLEEP -- curl -H "user-role: user" -H "x-request-id: test-123" -I http://httpbin.production.svc.cluster.local:8000/headers
```{{exec}}

```plain
# Test regular user without proper headers (should fail)
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/headers
```{{exec}}

```plain
# Test health check access
kubectl exec -n staging -it $STAGING_SLEEP -- curl -I http://httpbin.production.svc.cluster.local:8000/status/200
```{{exec}}

## Authorization Policy Debugging

### View Applied Policies

```plain
kubectl get authorizationpolicy -A
```{{exec}}

### Check Policy Details

```plain
kubectl describe authorizationpolicy complex-authorization -n production
```{{exec}}

### Debug Authorization Failures

Enable RBAC debug logging:

```plain
export PRODUCTION_HTTPBIN=$(kubectl get pod -n production -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config log -n production $PRODUCTION_HTTPBIN --level rbac:debug
```{{exec}}

Test a failing request and check logs:

```plain
kubectl exec -n staging -it $STAGING_SLEEP -- curl -X POST -I http://httpbin.production.svc.cluster.local:8000/post
```{{exec}}

```plain
kubectl logs -n production $PRODUCTION_HTTPBIN -c istio-proxy --tail=10 | grep -i rbac
```{{exec}}

Reset logging level:

```plain
istioctl proxy-config log -n production $PRODUCTION_HTTPBIN --level warning
```{{exec}}

## Advanced Authorization Best Practices

### 1. Principle of Least Privilege
- Start with default-deny policies
- Grant minimal necessary permissions
- Use specific paths and methods

### 2. Layer Security Controls
- Combine namespace, service account, and header-based rules
- Use multiple authorization policies for complex scenarios
- Implement defense in depth

### 3. Monitor and Audit
- Enable access logging for security events
- Use RBAC debug logging for troubleshooting
- Regular review of authorization policies

### 4. Service Account Strategy
- Create purpose-specific service accounts
- Use meaningful names that reflect roles
- Implement service account rotation policies

## Clean Up Resources

```plain
kubectl delete authorizationpolicy -n production --all
kubectl delete namespace production staging external
```{{exec}}

## Authorization Patterns Summary

| Pattern | Use Case | Implementation |
|---------|----------|----------------|
| **Namespace-based** | Multi-tenant isolation | `source.namespaces` |
| **Service Account** | Identity-based access | `source.principals` |
| **Header-based** | Role-based access control | `request.headers[role]` |
| **Path-based** | API endpoint protection | `operation.paths` |
| **Multi-condition** | Complex business rules | Multiple `when` conditions |

## Key Takeaways

1. **AuthorizationPolicy** supports complex multi-condition rules
2. **Namespace isolation** is critical for multi-tenant security  
3. **Service accounts** provide strong identity-based authorization
4. **Header-based authorization** enables role-based access control
5. **Path-based rules** provide granular API protection
6. **Default-deny** policies are security best practices
7. **Debug logging** is essential for troubleshooting authorization issues

These advanced authorization patterns are frequently tested in ICA exams and are essential for production Istio security!