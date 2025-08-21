#!/bin/bash

# wait for k8s ready
while ! kubectl get nodes | grep -w "Ready"; do
  echo "WAIT FOR NODES READY"
  sleep 1
done
touch /ks/.k8sfinished

# allow pods to run on controlplane
kubectl taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Install Istio 1.26.0 with demo profile
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
export PATH="$PATH:/root/istio-1.26.0/bin"
echo 'export PATH="$PATH:/root/istio-1.26.0/bin"' >> ~/.bashrc

# Install Istio with demo profile (includes ingress and egress gateways)
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/demo.yaml -y

# Enable sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

# Wait for Istio control plane to be ready
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s

# Wait for gateways to be ready
kubectl wait --for=condition=Ready pods -l app=istio-ingressgateway -n istio-system --timeout=300s
kubectl wait --for=condition=Ready pods -l app=istio-egressgateway -n istio-system --timeout=300s

# Deploy Bookinfo application for traffic management scenarios
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/bookinfo/platform/kube/bookinfo.yaml

# Deploy additional sample applications
kubectl apply -f /tmp/httpbin.yaml
kubectl apply -f /tmp/sleep-pod.yaml

# Wait for applications to be ready
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
kubectl wait --for=condition=Ready pods -l app=reviews --timeout=300s
kubectl wait --for=condition=Ready pods -l app=ratings --timeout=300s
kubectl wait --for=condition=Ready pods -l app=details --timeout=300s
kubectl wait --for=condition=Ready pods -l app=httpbin --timeout=300s
kubectl wait --for=condition=Ready pods -l app=sleep --timeout=300s

# Create multiple versions of reviews service for traffic shifting scenarios
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF

# Deploy external service simulator
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-service-simulator
  labels:
    app: external-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: external-service
  template:
    metadata:
      labels:
        app: external-service
    spec:
      containers:
      - name: external-service
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: external-service
  labels:
    app: external-service
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: external-service
EOF

# Wait for external service simulator
kubectl wait --for=condition=Ready pods -l app=external-service --timeout=120s

echo "Traffic Management environment ready!"
echo "Applications deployed: Bookinfo, httpbin, sleep, external-service-simulator"
echo "Istio gateways ready for ingress/egress scenarios"
echo "Multiple service versions available for traffic management testing"

# mark init finished
touch /ks/.initfinished