#!/bin/bash

# wait for k8s ready
while ! kubectl get nodes | grep -w "Ready"; do
  echo "WAIT FOR NODES READY"
  sleep 1
done
touch /ks/.k8sfinished

# allow pods to run on controlplane
kubectl taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Install Istio 1.26.0 with security-focused configuration
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
export PATH="$PATH:/root/istio-1.26.0/bin"
echo 'export PATH="$PATH:/root/istio-1.26.0/bin"' >> ~/.bashrc

# Install Istio with demo profile and enhanced security settings
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/demo.yaml -y

# Enable sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

# Create additional namespaces for security isolation scenarios
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace external

# Enable sidecar injection for additional namespaces
kubectl label namespace production istio-injection=enabled
kubectl label namespace staging istio-injection=enabled
kubectl label namespace external istio-injection=enabled

# Wait for Istio control plane to be ready
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s

# Deploy Bookinfo application for security scenarios
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/bookinfo/platform/kube/bookinfo.yaml

# Deploy httpbin for security testing
kubectl apply -f /tmp/httpbin.yaml

# Deploy sleep client for testing
kubectl apply -f /tmp/sleep-pod.yaml

# Wait for applications to be ready
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
kubectl wait --for=condition=Ready pods -l app=httpbin --timeout=300s
kubectl wait --for=condition=Ready pods -l app=sleep --timeout=300s

# Create service accounts with different roles for RBAC scenarios
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-sa
  labels:
    role: admin
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-sa
  labels:
    role: user
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: viewer-sa
  labels:
    role: viewer
EOF

# Deploy services in different namespaces for multi-tenant scenarios
kubectl apply -n production -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: production
  template:
    metadata:
      labels:
        app: httpbin
        version: production
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

# Wait for production httpbin
kubectl wait --for=condition=Ready pods -n production -l app=httpbin --timeout=120s

# Generate self-signed certificates for TLS scenarios
mkdir -p /tmp/certs
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout /tmp/certs/root-ca.key -out /tmp/certs/root-ca.crt
openssl req -out /tmp/certs/httpbin.csr -newkey rsa:2048 -nodes -keyout /tmp/certs/httpbin.key -subj "/CN=httpbin.example.com/O=httpbin organization"
openssl x509 -req -days 365 -CA /tmp/certs/root-ca.crt -CAkey /tmp/certs/root-ca.key -set_serial 0 -in /tmp/certs/httpbin.csr -out /tmp/certs/httpbin.crt

# Create TLS secret for gateway scenarios
kubectl create secret tls httpbin-credential --key=/tmp/certs/httpbin.key --cert=/tmp/certs/httpbin.crt -n istio-system

# Deploy a simple JWT token server for JWT authentication scenarios
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jwt-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jwt-server
  template:
    metadata:
      labels:
        app: jwt-server
    spec:
      containers:
      - name: jwt-server
        image: python:3.9-slim
        command: ["/bin/sh"]
        args:
        - -c
        - |
          pip install pyjwt cryptography
          cat > /tmp/jwt-server.py << 'EOF'
          import jwt
          import json
          from http.server import HTTPServer, BaseHTTPRequestHandler
          from datetime import datetime, timedelta
          
          SECRET_KEY = "test-secret-key"
          
          def create_token(user="test-user", role="user"):
              payload = {
                  "sub": user,
                  "role": role,
                  "iss": "testing@secure.istio.io",
                  "aud": "httpbin",
                  "exp": datetime.utcnow() + timedelta(hours=1),
                  "iat": datetime.utcnow()
              }
              return jwt.encode(payload, SECRET_KEY, algorithm="HS256")
          
          class JWTHandler(BaseHTTPRequestHandler):
              def do_GET(self):
                  if self.path == "/token":
                      token = create_token()
                      self.send_response(200)
                      self.send_header('Content-type', 'text/plain')
                      self.end_headers()
                      self.wfile.write(token.encode())
                  elif self.path.startswith("/token/"):
                      role = self.path.split("/")[-1]
                      token = create_token(role=role)
                      self.send_response(200)
                      self.send_header('Content-type', 'text/plain')
                      self.end_headers()
                      self.wfile.write(token.encode())
                  else:
                      self.send_response(404)
                      self.end_headers()
          
          server = HTTPServer(('0.0.0.0', 8080), JWTHandler)
          server.serve_forever()
          EOF
          python /tmp/jwt-server.py
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: jwt-server
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: jwt-server
EOF

# Wait for JWT server
kubectl wait --for=condition=Ready pods -l app=jwt-server --timeout=120s

echo "Security environment ready!"
echo "Applications deployed across multiple namespaces for security isolation"
echo "Service accounts created for RBAC scenarios"
echo "TLS certificates generated for edge security scenarios"
echo "JWT token server deployed for authentication scenarios"

# mark init finished
touch /ks/.initfinished