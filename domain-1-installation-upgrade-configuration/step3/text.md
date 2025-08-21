# Installing Istio in Sidecar Mode

Sidecar mode is the traditional Istio architecture where each workload gets a companion Envoy proxy container. Understanding sidecar mode is essential for the ICA exam as it's the foundational architecture pattern for service mesh.

## Understanding Sidecar Architecture

In sidecar mode:
- **Every pod** gets an Envoy proxy sidecar container
- **All traffic** (inbound and outbound) flows through the proxy
- **Policies** are enforced at the proxy level
- **Observability** data is collected by the proxy

## Clean Previous Installation

Let's start fresh to demonstrate sidecar mode clearly:

```plain
# Remove any previous Helm installations
helm uninstall istio-ingressgateway istio-egressgateway istiod istio-base -n istio-system 2>/dev/null || true
```{{exec}}

```plain
# Remove istioctl installation if it exists  
istioctl uninstall --purge -y 2>/dev/null || true
```{{exec}}

```plain
kubectl delete namespace istio-system --ignore-not-found
```{{exec}}

## Install Istio for Sidecar Mode

Install Istio with explicit sidecar mode configuration:

```plain
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/sidecar-injection-config.yaml -y
```{{exec}}

Wait for the control plane to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s
```{{exec}}

## Enable Sidecar Injection

Enable automatic sidecar injection for the default namespace:

```plain
kubectl label namespace default istio-injection=enabled
```{{exec}}

Verify the label was applied:

```plain
kubectl get namespace default --show-labels
```{{exec}}

## Deploy Application with Sidecar Injection

Deploy the Bookinfo application to see sidecar injection in action:

```plain
kubectl apply -f /tmp/bookinfo.yaml
```{{exec}}

Wait for the deployment:

```plain
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
```{{exec}}

## Verify Sidecar Injection

Check that each pod now has 2 containers (app + sidecar):

```plain
kubectl get pods
```{{exec}}

Get detailed view of containers in each pod:

```plain
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Examine Sidecar Configuration

Let's examine what the sidecar injection added:

```plain
kubectl describe pod -l app=productpage | grep -A 10 -B 5 istio-proxy
```{{exec}}

## Understanding Sidecar Injection Process

The sidecar injection happens via a mutating admission webhook:

```plain
kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o yaml | head -30
```{{exec}}

## Sidecar Configuration Template

View the sidecar injection template:

```plain
kubectl get configmap istio-sidecar-injector -n istio-system -o yaml | head -50
```{{exec}}

## Test Sidecar Functionality

Deploy a sleep client to test service-to-service communication:

```plain
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
EOF
```{{exec}}

Wait for sleep pod to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=sleep --timeout=120s
```{{exec}}

Verify it also has a sidecar:

```plain
kubectl get pods -l app=sleep -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Test Service-to-Service Communication

Test communication between services through sidecars:

```plain
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $SLEEP_POD -- curl -s http://productpage:9080/productpage | grep -o '<title>.*</title>'
```{{exec}}

## Examine Sidecar Proxy Configuration

Check the Envoy configuration in the sidecar:

```plain
istioctl proxy-config listeners $SLEEP_POD
```{{exec}}

```plain
istioctl proxy-config routes $SLEEP_POD
```{{exec}}

## Monitor Sidecar Traffic

Check access logs from the sidecar:

```plain
kubectl logs $SLEEP_POD -c istio-proxy --tail=10
```{{exec}}

## Sidecar Resource Usage

Check resource consumption of sidecars:

```plain
kubectl top pods
```{{exec}}

## Manual Sidecar Injection

You can also inject sidecars manually without automatic injection:

```plain
# Disable automatic injection for testing
kubectl label namespace default istio-injection-

# Create a deployment manifest
kubectl create deployment manual-test --image=nginx --dry-run=client -o yaml > /tmp/deployment.yaml

# Inject sidecar manually
istioctl kube-inject -f /tmp/deployment.yaml | kubectl apply -f -
```{{exec}}

Check the manually injected deployment:

```plain
kubectl get pods -l app=manual-test -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Re-enable Automatic Injection

```plain
kubectl label namespace default istio-injection=enabled
kubectl delete deployment manual-test
```{{exec}}

## Sidecar Injection Controls

### Per-Pod Injection Control

You can control injection per pod with annotations:

```plain
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-sidecar-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-sidecar-test
  template:
    metadata:
      labels:
        app: no-sidecar-test
      annotations:
        sidecar.istio.io/inject: "false"  # Disable injection for this pod
    spec:
      containers:
      - name: test
        image: nginx
EOF
```{{exec}}

Check that this pod has no sidecar:

```plain
kubectl get pods -l app=no-sidecar-test -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

Clean up:

```plain
kubectl delete deployment no-sidecar-test
```{{exec}}

## Sidecar Configuration Options

View sidecar configuration possibilities:

```plain
kubectl explain sidecar.networking.istio.io.spec
```{{exec}}

## Troubleshooting Sidecar Injection

Common sidecar injection issues:

```plain
# Check injection webhook
kubectl get mutatingwebhookconfiguration istio-sidecar-injector

# Check namespace labels
kubectl get namespace default --show-labels

# Check pod annotations
kubectl get pods -l app=productpage -o yaml | grep -A 5 -B 5 inject

# Verify webhook endpoint
kubectl get endpoints istio-sidecar-injector -n istio-system
```{{exec}}

## Sidecar Mode Advantages

- **Fine-grained control**: Per-workload policy enforcement
- **Rich observability**: Complete traffic visibility
- **Security**: mTLS for all communications
- **Compatibility**: Works with any application protocol

## Sidecar Mode Considerations

- **Resource overhead**: Additional memory and CPU per pod
- **Startup time**: Slightly longer pod initialization
- **Complexity**: More containers to manage
- **Network topology**: Additional network hops

## Clean Up

Remove test applications:

```plain
kubectl delete -f /tmp/bookinfo.yaml
kubectl delete deployment sleep
```{{exec}}

## Key Takeaways

- **Sidecar mode** is the traditional Istio architecture
- **Automatic injection** via namespace labeling is most common
- **Manual injection** provides fine-grained control
- **Every pod** gets an Envoy proxy sidecar
- **All traffic** flows through the sidecar proxy
- **Annotations** can override injection behavior

Understanding sidecar mode is fundamental for ICA exam success!