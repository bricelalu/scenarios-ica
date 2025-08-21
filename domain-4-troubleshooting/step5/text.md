# Troubleshooting Security Policies

Security policy issues are among the most challenging to troubleshoot because they often manifest as mysterious access denials or authentication failures. This step covers systematic debugging of mTLS, JWT, and authorization issues.

## mTLS Troubleshooting

mTLS (mutual TLS) issues are common in production Istio deployments:

### Check Overall mTLS Status

```plain
istioctl authn tls-check
```{{exec}}

### Test Specific Service mTLS

```plain
istioctl authn tls-check $SLEEP_POD productpage.default.svc.cluster.local
```{{exec}}

```plain
istioctl authn tls-check $SLEEP_POD reviews.default.svc.cluster.local
```{{exec}}

### Analyze PeerAuthentication Policies

```plain
kubectl get peerauthentication -A
```{{exec}}

Let's create a problematic mTLS configuration to troubleshoot:

```plain
kubectl apply -f /tmp/broken-mtls.yaml
```{{exec}}

### Diagnose mTLS Connection Issues

```plain
# Test connectivity after applying broken mTLS policy
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

Check what mTLS policy is affecting the connection:

```plain
istioctl authn tls-check $SLEEP_POD httpbin.default.svc.cluster.local
```{{exec}}

### Debug mTLS Certificate Chain

```plain
kubectl exec -it $SLEEP_POD -c istio-proxy -- curl -s localhost:15000/certs
```{{exec}}

### Fix mTLS Issues

Let's identify and fix the mTLS problem:

```plain
kubectl get peerauthentication broken-mtls -o yaml
```{{exec}}

The issue is likely incorrect mode or selector. Let's fix it:

```plain
kubectl delete peerauthentication broken-mtls
```{{exec}}

Verify the fix:

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

## JWT Authentication Troubleshooting

JWT issues often result in 401 Unauthorized or 403 Forbidden responses:

### Apply JWT Authentication Policy

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: httpbin-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.26/security/tools/jwt/samples/jwks.json"
    audiences:
    - httpbin
EOF
```{{exec}}

### Test Without JWT Token

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

### Get Valid JWT Token

```plain
TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.26/security/tools/jwt/samples/demo.jwt)
echo "JWT Token: $TOKEN"
```{{exec}}

### Test With Invalid Token

```plain
kubectl exec -it $SLEEP_POD -- curl -H "Authorization: Bearer invalid-token" -I http://httpbin:8000/headers
```{{exec}}

### Test With Valid Token

```plain
kubectl exec -it $SLEEP_POD -- curl -H "Authorization: Bearer $TOKEN" -I http://httpbin:8000/headers
```{{exec}}

### Debug JWT Validation Issues

Check Envoy logs for JWT-related errors:

```plain
export HTTPBIN_POD=$(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
kubectl logs $HTTPBIN_POD -c istio-proxy --tail=20 | grep -i jwt
```{{exec}}

### Inspect JWT Configuration in Envoy

```plain
istioctl proxy-config listeners $HTTPBIN_POD --port 8000 -o json | grep -A 10 -B 10 jwt
```{{exec}}

## Authorization Policy Troubleshooting

Authorization policies are often the most complex to debug:

### Apply Problematic Authorization Policy

```plain
kubectl apply -f /tmp/broken-authorization.yaml
```{{exec}}

### Test Access (Should Be Denied)

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

### Debug Authorization Policy

```plain
kubectl get authorizationpolicy broken-authz -o yaml
```{{exec}}

### Check Authorization Policy Evaluation

```plain
istioctl proxy-config listeners $HTTPBIN_POD --port 8000 -o json | grep -A 20 -B 5 rbac
```{{exec}}

### Enable Authorization Debug Logging

```plain
istioctl proxy-config log $HTTPBIN_POD --level rbac:debug
```{{exec}}

Test again and check logs:

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

```plain
kubectl logs $HTTPBIN_POD -c istio-proxy --tail=10 | grep -i rbac
```{{exec}}

### Fix Authorization Policy

The issue is likely incorrect source or action specification. Let's create a correct policy:

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: fixed-authz
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/sleep"]
    to:
    - operation:
        methods: ["GET", "POST"]
EOF
```{{exec}}

### Delete Broken Policy

```plain
kubectl delete authorizationpolicy broken-authz
```{{exec}}

### Verify Fix

```plain
kubectl exec -it $SLEEP_POD -- curl -I http://httpbin:8000/headers
```{{exec}}

Reset logging level:

```plain
istioctl proxy-config log $HTTPBIN_POD --level warning
```{{exec}}

## Advanced Security Troubleshooting

### Check Service Account and SPIFFE Identity

```plain
kubectl exec -it $SLEEP_POD -- cat /var/run/secrets/tokens/istio-token | cut -d. -f2 | base64 -d
```{{exec}}

### Verify Workload Identity

```plain
istioctl proxy-config secret $SLEEP_POD -o json | grep -A 10 -B 5 spiffe
```{{exec}}

### Debug RBAC Filter Chain

```plain
kubectl exec -it $HTTPBIN_POD -c istio-proxy -- curl -s localhost:15000/config_dump | grep -A 50 -B 10 rbac
```{{exec}}

## Security Policy Troubleshooting Workflow

When troubleshooting security issues, follow this systematic approach:

### 1. Identify the Security Layer
- **mTLS**: Connection/transport security
- **JWT**: Request authentication  
- **Authorization**: Access control

### 2. Check Policy Configuration
```bash
kubectl get peerauthentication,requestauthentication,authorizationpolicy -A
```

### 3. Test Connectivity
```bash
# Basic connectivity test
kubectl exec -it $CLIENT_POD -- curl -I http://target-service:port/path
```

### 4. Enable Debug Logging
```bash
# For mTLS issues
istioctl proxy-config log $POD --level debug

# For authorization issues  
istioctl proxy-config log $POD --level rbac:debug
```

### 5. Analyze Logs and Configuration
```bash
# Check sidecar logs
kubectl logs $POD -c istio-proxy --tail=50

# Check Envoy configuration
istioctl proxy-config listeners $POD --port $PORT
```

## Common Security Issues and Solutions

### ❌ mTLS Mode Conflicts
**Problem**: Mixed STRICT/PERMISSIVE modes causing connection failures
**Solution**: Ensure consistent PeerAuthentication policies

### ❌ JWT Audience Mismatch  
**Problem**: JWT audience doesn't match RequestAuthentication config
**Solution**: Verify `aud` claim matches policy audiences

### ❌ Authorization Principal Issues
**Problem**: Wrong service account principal in AuthorizationPolicy  
**Solution**: Use correct SPIFFE format: `cluster.local/ns/NAMESPACE/sa/SERVICE_ACCOUNT`

### ❌ Certificate Rotation Problems
**Problem**: Expired certificates causing mTLS failures
**Solution**: Check certificate expiration and rotation policies

## Security Troubleshooting Command Reference

```bash
# mTLS Diagnostics
istioctl authn tls-check $POD $SERVICE
istioctl proxy-config secret $POD

# JWT Debugging
kubectl logs $POD -c istio-proxy | grep jwt
istioctl proxy-config listeners $POD --port $PORT -o json

# Authorization Analysis
kubectl logs $POD -c istio-proxy | grep rbac
istioctl proxy-config listeners $POD --port $PORT -o json | grep rbac

# Security Policy Validation
istioctl analyze --all-namespaces
kubectl get peerauthentication,requestauthentication,authorizationpolicy -A
```

## Final Security Troubleshooting Tips

1. **Start with istioctl analyze** - catches many policy conflicts
2. **Test incrementally** - add one security policy at a time
3. **Use debug logging** - but remember to reset afterward
4. **Check service accounts** - ensure correct principals
5. **Verify certificates** - check expiration and chain validity
6. **Monitor proxy logs** - real-time debugging during tests

Congratulations! You've now mastered comprehensive Istio troubleshooting across all domains. These skills are essential for both the ICA exam and production Istio deployments.