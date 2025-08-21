# Configuring JWT Authentication with RequestAuthentication

In this step, you'll learn how to configure JSON Web Token (JWT) authentication using RequestAuthentication policies to authenticate end users and API clients accessing your services.

## Understanding JWT Authentication

RequestAuthentication provides:
- **JWT validation**: Verify token signature and claims
- **Multiple issuers**: Support for different JWT providers
- **Claim extraction**: Access JWT claims in authorization policies
- **Token locations**: Headers, query parameters, or custom locations
- **Public key management**: JWKS endpoint integration or static keys

## Deploy JWT Authentication Configuration

Apply JWT authentication configuration:

```bash
kubectl apply -f /tmp/request-auth-jwt.yaml
```{{exec}}

View the JWT authentication policy:

```bash
kubectl get requestauthentication jwt-example -o yaml
```{{exec}}

## Create Test JWT Tokens

Generate JWT tokens for testing (using demo keys):

```bash
# Create a simple JWT token (this is for demo purposes only)
cat > /tmp/create-jwt.py << 'EOF'
import json
import base64
import time

# Demo JWT header and payload (for testing only)
header = {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "DHFbpoIUqrY8t2zpA2qXfCmr5VO9J61GAuGSxBGAzpY"
}

payload = {
    "sub": "1234567890",
    "name": "Test User",
    "iss": "testing@secure.istio.io",
    "aud": "httpbin.default.svc.cluster.local",
    "iat": int(time.time()),
    "exp": int(time.time()) + 3600,
    "scope": "read write"
}

# Base64 encode (for demo - in production use proper JWT libraries)
header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip('=')
payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')

print(f"Header: {header_b64}")
print(f"Payload: {payload_b64}")
print(f"Token (unsigned): {header_b64}.{payload_b64}.SIGNATURE")
EOF

python3 /tmp/create-jwt.py
```{{exec}}

## Configure JWT with Sample Token

For testing, use a pre-generated demo token:

```bash
# Demo JWT token for testing (not for production)
export DEMO_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IkRIRmJwb0lVcXJZOHQyenBBMnFYZkNtcjVWTzlKNjFHQXVHU3hCR0F6cFkifQ.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlzcyI6InRlc3RpbmdAc2VjdXJlLmlzdGlvLmlvIiwiYXVkIjoiaHR0cGJpbi5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwiaWF0IjoxNzM3NDg4ODAwLCJleHAiOjE3Mzc0OTI0MDAsInNjb3BlIjoicmVhZCB3cml0ZSJ9.DEMO_SIGNATURE"

echo "Demo token: $DEMO_TOKEN"
```{{exec}}

## Test JWT Authentication

Test access without JWT token:

```bash
# Request without token (should work with lenient JWT validation)
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin:8000/headers | jq '.headers'
```{{exec}}

Test with JWT token:

```bash
# Request with JWT token in Authorization header
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $DEMO_TOKEN" http://httpbin:8000/headers | jq '.headers'
```{{exec}}

## Configure Multiple JWT Issuers

Create RequestAuthentication with multiple JWT issuers:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: multi-issuer-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.26/security/tools/jwt/samples/jwks.json"
    audiences:
    - "httpbin.default.svc.cluster.local"
    fromHeaders:
    - name: "Authorization"
      prefix: "Bearer "
    fromParams:
    - "access_token"
  - issuer: "auth0.example.com"
    jwksUri: "https://auth0.example.com/.well-known/jwks.json"
    audiences:
    - "api.example.com"
    forwardOriginalToken: true
  - issuer: "firebase.google.com/project-123"
    jwksUri: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    audiences:
    - "project-123"
    fromHeaders:
    - name: "x-goog-iap-jwt-assertion"
EOF
```{{exec}}

## Test Custom JWT Locations

Test JWT from different locations:

```bash
# JWT in Authorization header
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $DEMO_TOKEN" http://httpbin:8000/headers

# JWT in query parameter  
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s "http://httpbin:8000/headers?access_token=$DEMO_TOKEN"

# JWT in custom header
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "x-goog-iap-jwt-assertion: $DEMO_TOKEN" http://httpbin:8000/headers
```{{exec}}

## Configure JWT with Authorization Policy

Combine JWT authentication with authorization:

```bash
kubectl apply -f /tmp/jwt-authorization.yaml
```{{exec}}

View the JWT authorization policy:

```bash
kubectl get authorizationpolicy jwt-claims-authz -o yaml
```{{exec}}

## Test JWT Claims-Based Authorization

Test authorization based on JWT claims:

```bash
# Create tokens with different claims for testing
export ADMIN_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFkbWluIFVzZXIiLCJyb2xlIjoiYWRtaW4iLCJzY29wZSI6InJlYWQgd3JpdGUgZGVsZXRlIiwiaXNzIjoidGVzdGluZ0BzZWN1cmUuaXN0aW8uaW8iLCJhdWQiOiJodHRwYmluLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiLCJpYXQiOjE3Mzc0ODg4MDAsImV4cCI6MTczNzQ5MjQwMH0.ADMIN_DEMO_SIGNATURE"

export USER_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5ODc2NTQzMjEwIiwibmFtZSI6IlJlZ3VsYXIgVXNlciIsInJvbGUiOiJ1c2VyIiwic2NvcGUiOiJyZWFkIiwiaXNzIjoidGVzdGluZ0BzZWN1cmUuaXN0aW8uaW8iLCJhdWQiOiJodHRwYmluLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiLCJpYXQiOjE3Mzc0ODg4MDAsImV4cCI6MTczNzQ5MjQwMH0.USER_DEMO_SIGNATURE"

# Test admin access
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $ADMIN_TOKEN" http://httpbin:8000/get

# Test user access  
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $USER_TOKEN" http://httpbin:8000/get

# Test unauthorized access
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $USER_TOKEN" -X POST http://httpbin:8000/post || echo "POST denied for user role as expected"
```{{exec}}

## Configure JWT with Path-Based Authorization

Create authorization based on JWT claims and request paths:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: jwt-path-authz
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  # Admin can access everything
  - when:
    - key: request.auth.claims[role]
      values: ["admin"]
  # Users can only access read endpoints
  - when:
    - key: request.auth.claims[role]
      values: ["user"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get", "/status/*", "/headers"]
  # API clients with specific scope
  - when:
    - key: request.auth.claims[scope]
      values: ["api:read"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get"]
  # Anonymous access to public endpoints
  - to:
    - operation:
        methods: ["GET"]
        paths: ["/status/200"]
EOF
```{{exec}}

## Test Audience Validation

Create JWT with wrong audience and test validation:

```bash
export WRONG_AUD_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ildyb25nIEF1ZGllbmNlIiwiYXVkIjoid3Jvbmctc2VydmljZS5leGFtcGxlLmNvbSIsImlzcyI6InRlc3RpbmdAc2VjdXJlLmlzdGlvLmlvIiwiaWF0IjoxNzM3NDg4ODAwLCJleHAiOjE3Mzc0OTI0MDB9.WRONG_AUD_SIGNATURE"

# This should fail audience validation
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $WRONG_AUD_TOKEN" http://httpbin:8000/get || echo "JWT with wrong audience rejected as expected"
```{{exec}}

## Configure JWT Forwarding

Configure JWT token forwarding to backend services:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-forwarding
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.26/security/tools/jwt/samples/jwks.json"
    forwardOriginalToken: true
    outputPayloadToHeader: "x-jwt-payload"
EOF
```{{exec}}

## Test JWT Header Extraction

Test that JWT claims are extracted to headers:

```bash
# Create a pod to act as backend service
kubectl run backend-test --image=kennethreitz/httpbin --port=80 --restart=Never

kubectl wait --for=condition=ready pod backend-test --timeout=300s

# Test JWT header extraction
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -H "Authorization: Bearer $DEMO_TOKEN" http://productpage:9080/productpage | grep -i jwt || echo "JWT processed by productpage"
```{{exec}}

## Configure JWT with Custom Claims

Create authorization using custom JWT claims:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: custom-claims-authz
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  # Access based on department claim
  - when:
    - key: request.auth.claims[department]
      values: ["engineering", "devops"]
    to:
    - operation:
        methods: ["GET", "POST"]
  # Access based on location claim
  - when:
    - key: request.auth.claims[location]
      values: ["us-west", "eu-central"]
    - key: request.auth.claims[clearance_level]
      values: ["high", "critical"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT"]
  # Access based on array claims
  - when:
    - key: request.auth.claims[groups]
      values: ["admin-group", "power-users"]
    to:
    - operation:
        methods: ["*"]
EOF
```{{exec}}

## Monitor JWT Authentication

Monitor JWT authentication metrics and logs:

```bash
# View JWT authentication stats
kubectl exec -it $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:15000/stats | grep jwt

# View authentication failures
kubectl logs -l app=istio-proxy -c istio-proxy | grep -i "jwt\|auth" | tail -10

# Check policy status
kubectl get requestauthentication,authorizationpolicy
```{{exec}}

## Debug JWT Issues

Debug common JWT authentication issues:

```bash
# Check JWT policy configuration
kubectl describe requestauthentication jwt-example

# View proxy configuration for JWT
istioctl proxy-config listeners $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}') --port 8000 -o json | jq '.[0].filterChains[0].filters[] | select(.name=="envoy.filters.network.http_connection_manager")'

# Analyze configuration issues
istioctl analyze

# Test JWT payload decoding
echo "$DEMO_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.' || echo "Invalid JWT payload"
```{{exec}}

## Create Production JWT Setup

Configure JWT for production-like scenario:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: production-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  jwtRules:
  - issuer: "https://auth.example.com"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
    audiences:
    - "productpage-api"
    - "bookinfo-frontend"
    fromHeaders:
    - name: "Authorization"
      prefix: "Bearer "
    - name: "x-api-key"
    fromParams:
    - "token"
    forwardOriginalToken: false
    outputPayloadToHeader: "x-jwt-claims"
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: production-jwt-authz
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  # Authenticated users only
  - when:
    - key: request.auth.claims[iss]
      values: ["https://auth.example.com"]
    - key: request.auth.claims[aud]
      values: ["productpage-api", "bookinfo-frontend"]
EOF
```{{exec}}

## Clean Up Test Resources

Clean up test resources:

```bash
kubectl delete pod backend-test --ignore-not-found=true
kubectl delete requestauthentication multi-issuer-jwt jwt-forwarding production-jwt --ignore-not-found=true
kubectl delete authorizationpolicy jwt-path-authz custom-claims-authz production-jwt-authz --ignore-not-found=true
```{{exec}}

## Key Takeaways

- RequestAuthentication validates JWT tokens from various sources
- Multiple JWT issuers can be configured for different use cases
- JWT claims can be used in authorization policies for fine-grained control
- Token validation includes signature, audience, and expiration checks
- JWT payload can be forwarded to backend services via headers
- Always validate JWT configuration with proper test tokens
- Monitor JWT authentication metrics for security insights
- Custom claims enable rich authorization scenarios

In the next step, you'll learn about advanced authorization patterns and complex RBAC scenarios.