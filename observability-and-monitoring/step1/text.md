# Configure Telemetry v2 API

The Telemetry v2 API is Istio's modern approach to configuring observability. It provides more granular control over metrics, traces, and logs compared to the older EnvoyFilter approach.

Let's start by verifying our Istio installation supports Telemetry v2:

```plain
kubectl get pods -n istio-system
```{{exec}}

```plain
istioctl version
```{{exec}}

Now let's deploy the Bookinfo application to have some services to observe:

```plain
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.26.0/samples/bookinfo/platform/kube/bookinfo.yaml
```{{exec}}

Wait for the pods to be ready:

```plain
kubectl wait --for=condition=Ready pods --all --timeout=300s
```{{exec}}

## Configure Custom Metrics with Telemetry v2

Let's create a custom metric to track request durations. Apply the telemetry configuration:

```plain
kubectl apply -f /tmp/telemetry-v2-metrics.yaml
```{{exec}}

View the configuration:

```plain
kubectl get telemetry -A -o yaml
```{{exec}}

## Configure Access Logging

Enable detailed access logging for all workloads:

```plain
kubectl apply -f /tmp/telemetry-v2-logging.yaml
```{{exec}}

## Generate Some Traffic

Deploy a sleep pod to generate traffic:

```plain
kubectl apply -f /tmp/sleep-pod.yaml
```{{exec}}

Wait for the sleep pod to be ready:

```plain
kubectl wait --for=condition=Ready pod -l app=sleep --timeout=120s
```{{exec}}

Generate traffic to the productpage service:

```plain
for i in {1..10}; do
  kubectl exec -it deploy/sleep -- curl -s http://productpage:9080/productpage > /dev/null
  echo "Request $i completed"
  sleep 1
done
```{{exec}}

## Verify Custom Metrics

Check that our custom metrics are being collected:

```plain
kubectl exec -it deploy/sleep -- curl -s http://productpage:9080/stats/prometheus | grep request_duration
```{{exec}}

You should see custom metrics being generated. In the next step, we'll configure distributed tracing to track these requests across services.