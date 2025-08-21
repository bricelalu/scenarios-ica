#!/bin/bash

# wait for k8s ready
while ! kubectl get nodes | grep -w "Ready"; do
  echo "WAIT FOR NODES READY"
  sleep 1
done
touch /ks/.k8sfinished

# allow pods to run on controlplane
kubectl taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Install Istio with observability addons
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
export PATH="$PATH:/root/istio-1.26.0/bin"
echo 'export PATH="$PATH:/root/istio-1.26.0/bin"' >> ~/.bashrc

# Install Istio with demo profile and telemetry
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false --set values.telemetry.v2.enabled=true --set values.defaultRevision=default -y

# Enable sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

# Wait for Istio control plane to be ready
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s

# Deploy observability addons
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/addons/kiali.yaml

# Wait for addons to be ready
sleep 30
kubectl wait --for=condition=Ready pods -l app=jaeger -n istio-system --timeout=300s
kubectl wait --for=condition=Ready pods -l app=prometheus -n istio-system --timeout=300s
kubectl wait --for=condition=Ready pods -l app=grafana -n istio-system --timeout=300s
kubectl wait --for=condition=Ready pods -l app=kiali -n istio-system --timeout=300s

# mark init finished
touch /ks/.initfinished