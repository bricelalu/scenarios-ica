# Configuring Ingress and Egress Traffic with Gateways

In this step, you'll learn how to configure ingress and egress traffic using Istio Gateways. Gateways provide a way to configure load balancing for HTTP/TCP traffic at the edge of the mesh.

## Understanding Gateways

Istio Gateways:
- **Ingress Gateway**: Controls traffic entering the mesh
- **Egress Gateway**: Controls traffic leaving the mesh
- Work with VirtualServices to route traffic
- Support HTTP, HTTPS, TCP, and TLS protocols

## Install Istio and Deploy Test Applications

First, install Istio with the demo profile:

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
cd istio-1.26.0
export PATH=$PWD/bin:$PATH
istioctl install --set values.demo.profiles=demo -y
kubectl label namespace default istio-injection=enabled
```{{exec}}

Deploy test applications:

```bash
kubectl apply -f /tmp/bookinfo.yaml
kubectl apply -f /tmp/httpbin.yaml
kubectl apply -f /tmp/sleep-pod.yaml
```{{exec}}

Wait for all pods to be running:

```bash
kubectl get pods
```{{exec}}

## Configure Ingress Gateway

Create an ingress gateway to expose services to external traffic:

```bash
kubectl apply -f /tmp/ingress-gateway.yaml
```{{exec}}

View the ingress gateway configuration:

```bash
kubectl get gateway -o yaml
```{{exec}}

## Test Ingress Traffic

Get the ingress gateway external IP and ports:

```bash
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
export INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "Gateway URL: http://$GATEWAY_URL"
```{{exec}}

Test access to the bookinfo application:

```bash
curl -s "http://$GATEWAY_URL/productpage" | grep -o "<title>.*</title>"
```{{exec}}

## Configure Egress Gateway

Create an egress gateway to control outbound traffic:

```bash
kubectl apply -f /tmp/egress-gateway.yaml
```{{exec}}

Test egress traffic through the gateway:

```bash
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s http://httpbin.org/ip
```{{exec}}

## Verify Gateway Status

Check the status of all gateways:

```bash
kubectl get gateway
kubectl get virtualservice
```{{exec}}

Analyze gateway configuration:

```bash
istioctl analyze
```{{exec}}

## Key Takeaways

- Gateways control traffic at the mesh boundary
- Ingress gateways expose services to external clients
- Egress gateways secure and monitor outbound traffic
- Gateways work with VirtualServices for complete routing
- Always validate configuration with `istioctl analyze`

In the next step, you'll learn about VirtualService routing within the mesh.