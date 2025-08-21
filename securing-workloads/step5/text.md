# External Authorization and Advanced Security

External authorization allows you to integrate Istio with enterprise identity and access management systems. This provides fine-grained access control based on complex business logic that goes beyond simple JWT claims.

## Understanding External Authorization

External authorization works by:
1. **Intercepting requests** at the Istio proxy level
2. **Calling external service** to make authorization decisions
3. **Applying the decision** (allow/deny) to the request
4. **Optionally modifying** request headers based on authorization response

This enables integration with systems like:
- OAuth2/OIDC providers
- Enterprise RBAC systems
- Custom authorization services
- Policy engines (OPA, Cedar, etc.)

## Deploy External Authorization Service

Deploy a sample external authorization service:

```plain
kubectl apply -f /tmp/step5-external-authz.yaml
```{{exec}}

Wait for the service to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=ext-authz --timeout=120s
```{{exec}}

## Configure External Authorization Policy

Apply an AuthorizationPolicy that uses external authorization:

```plain
kubectl apply -f /tmp/step5-authz-policy-external.yaml
```{{exec}}

View the external authorization configuration:

```plain
kubectl get authorizationpolicy httpbin-ext-authz -o yaml
```{{exec}}

## Test External Authorization

The external authorization service checks for a specific header `x-user-role`.

Try accessing without the required header (should be denied):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" http://httpbin:8000/headers -o /dev/null
```{{exec}}

Try with an invalid role (should be denied):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" -H "x-user-role: guest" http://httpbin:8000/headers -o /dev/null
```{{exec}}

Try with a valid role (should succeed):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" -H "x-user-role: admin" http://httpbin:8000/headers -o /dev/null
```{{exec}}

## View External Authorization Service Logs

Check the external authorization service logs to see the authorization decisions:

```plain
kubectl logs -l app=ext-authz --tail=20
```{{exec}}

## Combine JWT and External Authorization

You can combine JWT authentication with external authorization for comprehensive security:

```plain
# Test with both JWT token and user role
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "x-user-role: admin" \
  http://httpbin:8000/headers -o /dev/null
```{{exec}}

## Security Best Practices Review

Let's review the security configurations we've implemented:

```plain
echo "=== Security Resources Summary ==="
kubectl get peerauthentication,requestauthentication,authorizationpolicy -A
```{{exec}}

```plain
echo "=== mTLS Status ==="
istioctl authn tls-check sleep.default httpbin.default
```{{exec}}

```plain
echo "=== Security Analysis ==="
istioctl analyze --all-namespaces
```{{exec}}

## Troubleshooting Security Issues

Common troubleshooting commands for security issues:

```plain
# Check proxy configuration
istioctl proxy-config listener sleep-<TAB> --port 15006

# Check authentication policies
istioctl proxy-config cluster sleep-<TAB> --fqdn httpbin.default.svc.cluster.local

# View security logs
kubectl logs -l app=sleep -c istio-proxy --tail=10
```{{exec}}

Congratulations! You've mastered advanced Istio security patterns including mTLS, authorization policies, JWT authentication, and external authorization integration. These skills are essential for securing production workloads in Istio service mesh.