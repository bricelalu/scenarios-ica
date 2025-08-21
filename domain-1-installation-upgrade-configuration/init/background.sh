#!/bin/bash

# wait for k8s ready
while ! kubectl get nodes | grep -w "Ready"; do
  echo "WAIT FOR NODES READY"
  sleep 1
done
touch /ks/.k8sfinished

# allow pods to run on controlplane
kubectl taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Install Helm (for Helm installation scenarios)
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# Download Istio 1.26.0
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
export PATH="$PATH:/root/istio-1.26.0/bin"
echo 'export PATH="$PATH:/root/istio-1.26.0/bin"' >> ~/.bashrc

# Download Istio Helm charts
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Prepare for ambient mesh installation
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Copy Istio binary to standard location for easy access
cp /root/istio-1.26.0/bin/istioctl /usr/local/bin/

# Create necessary directories for scenarios
mkdir -p /root/profiles
mkdir -p /root/helm-configs
mkdir -p /root/certs

# Copy demo profiles to easily accessible location
cp /root/istio-1.26.0/manifests/profiles/*.yaml /root/profiles/

echo "Istio 1.26.0 and Helm installed successfully"
echo "Available installation methods ready: istioctl, Helm"
echo "Ambient Mesh prerequisites installed"
echo "Gateway API CRDs installed for Gateway API integration scenarios"

# mark init finished
touch /ks/.initfinished