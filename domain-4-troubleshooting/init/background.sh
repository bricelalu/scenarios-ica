#!/bin/bash

# wait for k8s ready
while ! kubectl get nodes | grep -w "Ready"; do
  echo "WAIT FOR NODES READY"
  sleep 1
done
touch /ks/.k8sfinished

# allow pods to run on controlplane
kubectl taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Install Istio with demo profile
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
export PATH="$PATH:/root/istio-1.26.0/bin"
echo 'export PATH="$PATH:/root/istio-1.26.0/bin"' >> ~/.bashrc

# Install Istio with demo profile
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/demo.yaml -y

# Enable sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

# Wait for Istio control plane to be ready
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s

# Deploy sample applications
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f /tmp/httpbin.yaml
kubectl apply -f /tmp/sleep-pod.yaml

# Wait for applications to be ready
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
kubectl wait --for=condition=Ready pods -l app=httpbin --timeout=300s
kubectl wait --for=condition=Ready pods -l app=sleep --timeout=300s

# Deploy some broken configurations for troubleshooting practice
kubectl apply -f /tmp/broken-virtualservice.yaml --dry-run=client
kubectl apply -f /tmp/broken-destinationrule.yaml --dry-run=client
kubectl apply -f /tmp/broken-gateway.yaml --dry-run=client

# mark init finished
touch /ks/.initfinished