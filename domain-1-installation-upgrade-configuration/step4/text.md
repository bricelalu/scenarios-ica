# Installing Istio in Ambient Mode

Ambient mode is Istio's revolutionary sidecar-less architecture that provides service mesh capabilities without injecting sidecar containers. This modern approach is increasingly important for ICA certification as it represents the future of service mesh.

## Understanding Ambient Architecture

Ambient mode uses:
- **ztunnel**: Secure overlay for L4 processing (per-node DaemonSet)
- **waypoint proxies**: Optional L7 processing (per-service/namespace)
- **No sidecars**: Applications run unmodified
- **Gradual adoption**: Opt-in L7 policies per workload

## Prerequisites for Ambient Mode

Ambient mode requires Gateway API CRDs (already installed during initialization):

```plain
kubectl get crd gateways.gateway.networking.k8s.io
```{{exec}}

## Clean Previous Installation

Remove sidecar mode installation to start fresh:

```plain
kubectl delete -f /tmp/bookinfo.yaml 2>/dev/null || true
kubectl label namespace default istio-injection- 2>/dev/null || true
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found
```{{exec}}

## Install Istio for Ambient Mode

Install Istio with ambient mode enabled:

```plain
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/ambient-mesh-config.yaml -y
```{{exec}}

Wait for the control plane to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=istiod -n istio-system --timeout=300s
```{{exec}}

## Verify Ambient Components

Check that ambient-specific components are installed:

```plain
kubectl get pods -n istio-system
```{{exec}}

Look for the ztunnel DaemonSet:

```plain
kubectl get daemonset -n istio-system
```{{exec}}

```plain
kubectl get pods -n istio-system -l app=ztunnel
```{{exec}}

## Enable Ambient Mode for Namespace

Enable ambient mode for the default namespace:

```plain
kubectl label namespace default istio.io/dataplane-mode=ambient
```{{exec}}

Verify the label:

```plain
kubectl get namespace default --show-labels
```{{exec}}

## Deploy Application in Ambient Mode

Deploy the Bookinfo application (no sidecar injection needed):

```plain
kubectl apply -f /tmp/bookinfo.yaml
```{{exec}}

Wait for the deployment:

```plain
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
```{{exec}}

## Verify Ambient Mode Operation

Check that pods have NO sidecar containers:

```plain
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

Notice each pod has only 1 container (no istio-proxy sidecar).

## Deploy Sleep Client

Deploy a client for testing:

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

```plain
kubectl wait --for=condition=Ready pods -l app=sleep --timeout=120s
```{{exec}}

## Test L4 Connectivity

Test that basic connectivity works in ambient mode:

```plain
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $SLEEP_POD -- curl -s http://productpage:9080/productpage | grep -o '<title>.*</title>'
```{{exec}}

## Understand L4 vs L7 Processing

In ambient mode:
- **L4 policies** (mTLS, basic authorization) work automatically via ztunnel
- **L7 policies** (HTTP routing, advanced security) require waypoint proxies

## Check mTLS Status

Verify that mTLS is automatically enabled:

```plain
istioctl authn tls-check $SLEEP_POD productpage.default.svc.cluster.local
```{{exec}}

## View ztunnel Configuration

Check how ztunnel is configured:

```plain
kubectl logs -n istio-system -l app=ztunnel --tail=10
```{{exec}}

## Enable L7 Processing with Waypoint Proxy

To use L7 features, deploy a waypoint proxy for the productpage service:

```plain
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: productpage-waypoint
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
EOF
```{{exec}}

Wait for the waypoint proxy:

```plain
kubectl wait --for=condition=Programmed gateway productpage-waypoint --timeout=120s
```{{exec}}

## Label Service for Waypoint Usage

Configure the productpage service to use the waypoint proxy:

```plain
kubectl label service productpage istio.io/use-waypoint=productpage-waypoint
```{{exec}}

## Verify Waypoint Proxy Deployment

Check that waypoint proxy pod is running:

```plain
kubectl get pods -l istio.io/gateway-name=productpage-waypoint
```{{exec}}

## Test L7 Functionality

Now we can apply L7 policies. Create a VirtualService:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: productpage
spec:
  hosts:
  - productpage
  http:
  - match:
    - headers:
        user-agent:
          prefix: curl
    route:
    - destination:
        host: productpage
      headers:
        response:
          add:
            x-ambient-test: "waypoint-processed"
  - route:
    - destination:
        host: productpage
EOF
```{{exec}}

Test that L7 processing works:

```plain
kubectl exec -it $SLEEP_POD -- curl -v http://productpage:9080 2>&1 | grep x-ambient-test
```{{exec}}

## Compare Resource Usage

Check resource usage compared to sidecar mode:

```plain
kubectl top pods
```{{exec}}

```plain
kubectl top nodes
```{{exec}}

Notice the reduced per-pod overhead compared to sidecar mode.

## Ambient Mode Policies

Let's apply a simple authorization policy:

```plain
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-policy
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/default"]
    to:
    - operation:
        methods: ["GET"]
EOF
```{{exec}}

Test that the policy is enforced:

```plain
kubectl exec -it $SLEEP_POD -- curl -s -w "%{http_code}" http://productpage:9080 -o /dev/null
```{{exec}}

## Gradual Migration from Sidecar

Ambient mode supports gradual migration. You can have some services in ambient mode and others in sidecar mode:

```plain
# Create a namespace with sidecar injection
kubectl create namespace sidecar-test
kubectl label namespace sidecar-test istio-injection=enabled

# Deploy an app with sidecars
kubectl apply -n sidecar-test -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
EOF
```{{exec}}

```plain
kubectl wait --for=condition=Ready pods -n sidecar-test -l app=httpbin --timeout=120s
```{{exec}}

Compare the architectures:

```plain
echo "=== Ambient Mode (default namespace) ==="
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"

echo "=== Sidecar Mode (sidecar-test namespace) ==="
kubectl get pods -n sidecar-test -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Ambient Mode Advantages

- **Reduced resource overhead**: No sidecar containers
- **Faster startup**: No proxy initialization delay
- **Simplified operations**: Fewer containers to manage
- **Gradual adoption**: Opt-in L7 processing
- **Backward compatibility**: Works alongside sidecar mode

## Ambient Mode Considerations

- **Newer technology**: Less mature than sidecar mode
- **L7 complexity**: Requires waypoint proxies for advanced features
- **Debugging**: Different troubleshooting approaches
- **Feature parity**: Some features still evolving

## Clean Up

Remove test resources:

```plain
kubectl delete -f /tmp/bookinfo.yaml
kubectl delete deployment sleep
kubectl delete gateway productpage-waypoint
kubectl delete virtualservice productpage
kubectl delete authorizationpolicy productpage-policy
kubectl delete namespace sidecar-test
kubectl label namespace default istio.io/dataplane-mode-
```{{exec}}

## Ambient vs Sidecar Comparison

| Aspect | Ambient Mode | Sidecar Mode |
|--------|--------------|--------------|
| **Architecture** | Node-level ztunnel + optional waypoints | Per-pod sidecars |
| **Resource Usage** | Lower per-pod overhead | Higher per-pod overhead |
| **L4 Policies** | Automatic via ztunnel | Via sidecar proxy |
| **L7 Policies** | Requires waypoint proxy | Via sidecar proxy |
| **Startup Time** | Faster (no sidecar init) | Slower (proxy startup) |
| **Maturity** | Newer, evolving | Mature, stable |
| **Migration** | Gradual, namespace-level | All-or-nothing |

## Key Takeaways

- **Ambient mode** eliminates sidecar containers
- **ztunnel** provides L4 security and connectivity
- **Waypoint proxies** enable L7 processing when needed
- **Gradual adoption** allows mixed deployments
- **Resource efficiency** with lower per-pod overhead
- **Gateway API** integration for modern Kubernetes

Ambient mode represents the future of service mesh architecture and is increasingly important for ICA certification!