# Securing Edge Traffic with TLS termination and certificates

In this step, you'll learn how to secure edge traffic using TLS termination, certificate management, and advanced gateway security configurations to protect external-facing services.

## Understanding Edge Security

Edge security components include:
- **TLS termination**: Decrypt HTTPS traffic at the gateway
- **Certificate management**: Automated certificate provisioning and rotation
- **SNI support**: Multiple domains with different certificates
- **HTTPS redirect**: Automatic HTTP to HTTPS redirection
- **Certificate validation**: Client certificate verification
- **Security headers**: HSTS, CSP, and other security headers

## Deploy TLS Gateway Configuration

Apply TLS gateway configuration:

```bash
kubectl apply -f /tmp/tls-gateway-certs.yaml
```{{exec}}

View the TLS gateway configuration:

```bash
kubectl get gateway tls-gateway -o yaml
```{{exec}}

## Create Self-Signed Certificates

Generate self-signed certificates for testing:

```bash
# Create certificate directory
mkdir -p /tmp/certs

# Generate root CA private key
openssl genrsa -out /tmp/certs/root-key.pem 4096

# Generate root CA certificate
openssl req -new -x509 -key /tmp/certs/root-key.pem -sha256 -subj "/C=US/ST=CA/O=Istio/CN=Root CA" -days 365 -out /tmp/certs/root-cert.pem

# Generate server private key
openssl genrsa -out /tmp/certs/httpbin-key.pem 4096

# Generate certificate signing request
openssl req -new -key /tmp/certs/httpbin-key.pem -out /tmp/certs/httpbin.csr -subj "/C=US/ST=CA/O=Httpbin/CN=httpbin.example.com"

# Generate server certificate
openssl x509 -req -in /tmp/certs/httpbin.csr -CA /tmp/certs/root-cert.pem -CAkey /tmp/certs/root-key.pem -CAcreateserial -out /tmp/certs/httpbin-cert.pem -days 365 -sha256 -extfile <(echo "subjectAltName=DNS:httpbin.example.com,DNS:*.httpbin.example.com")
```{{exec}}

## Create TLS Secret

Create Kubernetes secrets for TLS certificates:

```bash
# Create TLS secret for httpbin
kubectl create secret tls httpbin-credential --key=/tmp/certs/httpbin-key.pem --cert=/tmp/certs/httpbin-cert.pem -n istio-system

# Create CA certificate secret
kubectl create secret generic httpbin-ca-credential --from-file=root-cert.pem=/tmp/certs/root-cert.pem -n istio-system
```{{exec}}

## Configure HTTPS Gateway

Create HTTPS gateway with TLS termination:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-https-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: httpbin-credential
    hosts:
    - httpbin.example.com
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.example.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-https-vs
spec:
  hosts:
  - httpbin.example.com
  gateways:
  - httpbin-https-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test HTTPS Access

Test HTTPS access to the service:

```bash
# Get gateway external IP
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
export SECURE_INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

echo "HTTPS Gateway URL: https://$INGRESS_HOST:$SECURE_INGRESS_PORT"

# Test HTTPS with self-signed certificate
curl -v -HHost:httpbin.example.com --resolve "httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://httpbin.example.com:$SECURE_INGRESS_PORT/status/200"
```{{exec}}

## Configure HTTP to HTTPS Redirect

Add HTTP to HTTPS redirection:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-redirect-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  # HTTPS server
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: httpbin-credential
    hosts:
    - httpbin.example.com
  # HTTP server with redirect
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.example.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-redirect-vs
spec:
  hosts:
  - httpbin.example.com
  gateways:
  - httpbin-redirect-gateway
  http:
  # Redirect HTTP to HTTPS
  - match:
    - port: 80
    redirect:
      scheme: https
      redirectCode: 301
  # HTTPS traffic routing
  - match:
    - port: 443
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test HTTP Redirect

Test HTTP to HTTPS redirection:

```bash
export INSECURE_INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# Test HTTP redirect
curl -I -HHost:httpbin.example.com http://$INGRESS_HOST:$INSECURE_INGRESS_PORT/status/200
```{{exec}}

## Configure Mutual TLS (mTLS) at Gateway

Set up mTLS for client certificate authentication:

```bash
# Generate client certificates
openssl genrsa -out /tmp/certs/client-key.pem 4096
openssl req -new -key /tmp/certs/client-key.pem -out /tmp/certs/client.csr -subj "/C=US/ST=CA/O=Client/CN=client.example.com"
openssl x509 -req -in /tmp/certs/client.csr -CA /tmp/certs/root-cert.pem -CAkey /tmp/certs/root-key.pem -CAcreateserial -out /tmp/certs/client-cert.pem -days 365 -sha256

# Create client certificate secret
kubectl create secret generic httpbin-client-credential --from-file=tls.key=/tmp/certs/client-key.pem --from-file=tls.crt=/tmp/certs/client-cert.pem --from-file=ca.crt=/tmp/certs/root-cert.pem -n istio-system

# Create mTLS gateway
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-mtls-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https-mtls
      protocol: HTTPS
    tls:
      mode: MUTUAL
      credentialName: httpbin-credential
      caCertificates: /etc/ssl/certs/root-cert.pem
    hosts:
    - secure.httpbin.example.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-mtls-vs
spec:
  hosts:
  - secure.httpbin.example.com
  gateways:
  - httpbin-mtls-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test mTLS Authentication

Test mTLS client authentication:

```bash
# Test with client certificate
curl -v -HHost:secure.httpbin.example.com --resolve "secure.httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem --cert /tmp/certs/client-cert.pem --key /tmp/certs/client-key.pem "https://secure.httpbin.example.com:$SECURE_INGRESS_PORT/status/200"

# Test without client certificate (should fail)
curl -v -HHost:secure.httpbin.example.com --resolve "secure.httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://secure.httpbin.example.com:$SECURE_INGRESS_PORT/status/200" || echo "mTLS authentication required"
```{{exec}}

## Deploy Edge Termination Configuration

Apply comprehensive edge termination configuration:

```bash
kubectl apply -f /tmp/tls-edge-termination.yaml
```{{exec}}

View the edge termination configuration:

```bash
kubectl get gateway tls-edge-gateway -o yaml
```{{exec}}

## Configure SNI Support

Set up Server Name Indication for multiple domains:

```bash
# Generate certificates for multiple domains
openssl genrsa -out /tmp/certs/api-key.pem 4096
openssl req -new -key /tmp/certs/api-key.pem -out /tmp/certs/api.csr -subj "/C=US/ST=CA/O=API/CN=api.example.com"
openssl x509 -req -in /tmp/certs/api.csr -CA /tmp/certs/root-cert.pem -CAkey /tmp/certs/root-key.pem -CAcreateserial -out /tmp/certs/api-cert.pem -days 365 -sha256

openssl genrsa -out /tmp/certs/web-key.pem 4096
openssl req -new -key /tmp/certs/web-key.pem -out /tmp/certs/web.csr -subj "/C=US/ST=CA/O=Web/CN=web.example.com"
openssl x509 -req -in /tmp/certs/web.csr -CA /tmp/certs/root-cert.pem -CAkey /tmp/certs/root-key.pem -CAcreateserial -out /tmp/certs/web-cert.pem -days 365 -sha256

# Create secrets for multiple domains
kubectl create secret tls api-credential --key=/tmp/certs/api-key.pem --cert=/tmp/certs/api-cert.pem -n istio-system
kubectl create secret tls web-credential --key=/tmp/certs/web-key.pem --cert=/tmp/certs/web-cert.pem -n istio-system
```{{exec}}

## Create Multi-Domain Gateway

Configure gateway with multiple TLS certificates:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: multi-domain-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  # API domain
  - port:
      number: 443
      name: https-api
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: api-credential
    hosts:
    - api.example.com
  # Web domain
  - port:
      number: 443
      name: https-web
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: web-credential
    hosts:
    - web.example.com
  # Default domain
  - port:
      number: 443
      name: https-default
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: httpbin-credential
    hosts:
    - httpbin.example.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: multi-domain-vs
spec:
  hosts:
  - api.example.com
  - web.example.com
  - httpbin.example.com
  gateways:
  - multi-domain-gateway
  http:
  # API traffic
  - match:
    - headers:
        ":authority":
          exact: api.example.com
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
      headers:
        request:
          add:
            x-service-type: api
  # Web traffic
  - match:
    - headers:
        ":authority":
          exact: web.example.com
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
      headers:
        request:
          add:
            x-service-type: web
  # Default traffic
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Test SNI Support

Test Server Name Indication with different domains:

```bash
# Test API domain
curl -v -HHost:api.example.com --resolve "api.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://api.example.com:$SECURE_INGRESS_PORT/headers" | jq '.headers["X-Service-Type"]'

# Test Web domain
curl -v -HHost:web.example.com --resolve "web.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://web.example.com:$SECURE_INGRESS_PORT/headers" | jq '.headers["X-Service-Type"]'

# Test default domain
curl -v -HHost:httpbin.example.com --resolve "httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://httpbin.example.com:$SECURE_INGRESS_PORT/headers"
```{{exec}}

## Configure Security Headers

Add security headers to responses:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: security-headers
  namespace: istio-system
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inline_code: |
            function envoy_on_response(response_handle)
              response_handle:headers():add("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
              response_handle:headers():add("X-Frame-Options", "SAMEORIGIN")
              response_handle:headers():add("X-Content-Type-Options", "nosniff")
              response_handle:headers():add("X-XSS-Protection", "1; mode=block")
              response_handle:headers():add("Referrer-Policy", "strict-origin-when-cross-origin")
              response_handle:headers():add("Content-Security-Policy", "default-src 'self'")
            end
EOF
```{{exec}}

## Test Security Headers

Test that security headers are added:

```bash
curl -I -HHost:httpbin.example.com --resolve "httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" --cacert /tmp/certs/root-cert.pem "https://httpbin.example.com:$SECURE_INGRESS_PORT/status/200"
```{{exec}}

## Configure Certificate Rotation

Set up automated certificate rotation monitoring:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cert-monitor-script
  namespace: istio-system
data:
  monitor.sh: |
    #!/bin/bash
    while true; do
      echo "Checking certificate expiration..."
      
      # Check each certificate
      for secret in httpbin-credential api-credential web-credential; do
        if kubectl get secret \$secret -n istio-system >/dev/null 2>&1; then
          cert_data=\$(kubectl get secret \$secret -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d)
          expiry=\$(echo "\$cert_data" | openssl x509 -noout -enddate | cut -d= -f2)
          expiry_epoch=\$(date -d "\$expiry" +%s)
          current_epoch=\$(date +%s)
          days_until_expiry=\$(( (expiry_epoch - current_epoch) / 86400 ))
          
          echo "Certificate \$secret expires in \$days_until_expiry days"
          
          if [ \$days_until_expiry -lt 30 ]; then
            echo "WARNING: Certificate \$secret expires in less than 30 days!"
          fi
        fi
      done
      
      sleep 3600  # Check every hour
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-monitor
  namespace: istio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-monitor
  template:
    metadata:
      labels:
        app: cert-monitor
    spec:
      containers:
      - name: monitor
        image: bitnami/kubectl
        command: ["/bin/bash", "/scripts/monitor.sh"]
        volumeMounts:
        - name: script
          mountPath: /scripts
      volumes:
      - name: script
        configMap:
          name: cert-monitor-script
          defaultMode: 0755
EOF
```{{exec}}

## Monitor TLS Configuration

Monitor TLS configuration and certificate status:

```bash
# Check TLS configuration
istioctl proxy-config listeners $(kubectl get pod -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}') -n istio-system --port 443

# Check certificate details
kubectl get secret httpbin-credential -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 2 "Subject:"

# Check certificate expiration
kubectl get secret httpbin-credential -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Monitor gateway configuration
kubectl get gateway --all-namespaces
```{{exec}}

## Test Certificate Validation

Validate certificate chain and trust:

```bash
# Verify certificate chain
echo | openssl s_client -connect $INGRESS_HOST:$SECURE_INGRESS_PORT -servername httpbin.example.com -CAfile /tmp/certs/root-cert.pem 2>/dev/null | openssl x509 -noout -subject -issuer

# Check certificate trust chain
openssl verify -CAfile /tmp/certs/root-cert.pem /tmp/certs/httpbin-cert.pem

# Test certificate revocation (if applicable)
echo | openssl s_client -connect $INGRESS_HOST:$SECURE_INGRESS_PORT -servername httpbin.example.com 2>/dev/null | openssl x509 -noout -text | grep -i "crl\|ocsp"
```{{exec}}

## Configure Advanced TLS Settings

Configure advanced TLS parameters:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: advanced-tls-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https-advanced
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: httpbin-credential
      minProtocolVersion: TLSV1_2
      maxProtocolVersion: TLSV1_3
      cipherSuites:
      - "ECDHE-RSA-AES256-GCM-SHA384"
      - "ECDHE-RSA-AES128-GCM-SHA256"
    hosts:
    - secure.httpbin.example.com
EOF
```{{exec}}

## Test Advanced TLS Configuration

Test advanced TLS settings:

```bash
# Test TLS version support
echo | openssl s_client -connect $INGRESS_HOST:$SECURE_INGRESS_PORT -servername secure.httpbin.example.com -tls1_2 2>/dev/null | grep "Protocol :"

echo | openssl s_client -connect $INGRESS_HOST:$SECURE_INGRESS_PORT -servername secure.httpbin.example.com -tls1_3 2>/dev/null | grep "Protocol :" || echo "TLS 1.3 not available"

# Test cipher suites
echo | openssl s_client -connect $INGRESS_HOST:$SECURE_INGRESS_PORT -servername secure.httpbin.example.com 2>/dev/null | grep "Cipher :"
```{{exec}}

## Clean Up

Clean up test resources:

```bash
# Remove certificate files
rm -rf /tmp/certs

# Remove certificate secrets
kubectl delete secret httpbin-credential api-credential web-credential httpbin-ca-credential httpbin-client-credential -n istio-system --ignore-not-found=true

# Remove gateways and virtual services
kubectl delete gateway httpbin-https-gateway httpbin-redirect-gateway httpbin-mtls-gateway multi-domain-gateway advanced-tls-gateway --ignore-not-found=true
kubectl delete virtualservice httpbin-https-vs httpbin-redirect-vs httpbin-mtls-vs multi-domain-vs --ignore-not-found=true

# Remove security filters
kubectl delete envoyfilter security-headers -n istio-system --ignore-not-found=true

# Remove monitoring
kubectl delete deployment cert-monitor -n istio-system --ignore-not-found=true
kubectl delete configmap cert-monitor-script -n istio-system --ignore-not-found=true
```{{exec}}

## Key Takeaways

- TLS termination at the gateway provides centralized certificate management
- SNI support enables multiple domains with different certificates
- mTLS at the gateway provides strong client authentication
- HTTP to HTTPS redirection ensures encrypted communication
- Security headers enhance client-side security
- Certificate rotation monitoring prevents service disruptions
- Advanced TLS settings improve security posture
- Always use proper certificate validation in production
- Monitor certificate expiration and renewal processes

Congratulations! You have completed Domain 3: Securing Workloads. You've learned comprehensive security including authorization policies, mTLS and JWT authentication, advanced RBAC patterns, and edge traffic protection with TLS.