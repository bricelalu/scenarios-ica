# Implement JWT Authentication

JSON Web Tokens (JWT) provide a standardized way to securely transmit information between parties. In Istio, you can configure JWT authentication using the `RequestAuthentication` resource, which validates JWT tokens at the ingress gateway or service level.

## Understanding JWT Authentication Flow

1. **Client** obtains JWT token from identity provider
2. **Client** includes token in HTTP Authorization header  
3. **Istio proxy** validates token signature and claims
4. **Request** is allowed/denied based on token validity

Let's implement JWT authentication for the httpbin service.

## Deploy a Simple JWT Issuer

First, let's create a mock JWT issuer service that will provide tokens for testing:

```plain
kubectl apply -f /tmp/step4-jwt-issuer.yaml
```{{exec}}

Wait for the JWT issuer to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=jwt-issuer --timeout=120s
```{{exec}}

## Configure RequestAuthentication

Apply the RequestAuthentication resource to validate JWT tokens:

```plain
kubectl apply -f /tmp/step4-request-authentication.yaml
```{{exec}}

View the RequestAuthentication configuration:

```plain
kubectl get requestauthentication httpbin-jwt -o yaml
```{{exec}}

## Test JWT Authentication

First, try accessing httpbin without a token (should still work as RequestAuthentication only validates, doesn't enforce):

```plain
kubectl exec -it deploy/sleep -- curl -s http://httpbin:8000/headers
```{{exec}}

Now let's get a valid JWT token from our issuer:

```plain
JWT_TOKEN=$(kubectl exec -it deploy/sleep -- curl -s http://jwt-issuer:8080/token)
echo "JWT Token: $JWT_TOKEN"
```{{exec}}

Access httpbin with the JWT token:

```plain
kubectl exec -it deploy/sleep -- curl -s -H "Authorization: Bearer $JWT_TOKEN" http://httpbin:8000/headers
```{{exec}}

## Configure Authorization Policy for JWT

Now let's create an AuthorizationPolicy that requires valid JWT tokens:

```plain
kubectl apply -f /tmp/step4-jwt-authz-policy.yaml
```{{exec}}

## Test JWT Authorization

Try accessing without a token (should be denied):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" http://httpbin:8000/headers -o /dev/null
```{{exec}}

Try with an invalid token (should be denied):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" -H "Authorization: Bearer invalid-token" http://httpbin:8000/headers -o /dev/null
```{{exec}}

Try with a valid token (should succeed):

```plain
kubectl exec -it deploy/sleep -- curl -s -w "%{http_code}" -H "Authorization: Bearer $JWT_TOKEN" http://httpbin:8000/headers -o /dev/null
```{{exec}}

## Verify JWT Claims

View the JWT token payload to understand what claims are being validated:

```plain
kubectl exec -it deploy/sleep -- curl -s http://jwt-issuer:8080/decode/$JWT_TOKEN
```{{exec}}

Excellent! You've successfully configured JWT authentication with Istio. In the next step, we'll explore external authorization for even more sophisticated access control patterns.