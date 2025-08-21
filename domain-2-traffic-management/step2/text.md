# Configuring Routing within a Service Mesh with VirtualService

In this step, you'll master VirtualService configuration for advanced traffic routing within the service mesh, including host-based routing, path-based routing, and header-based routing.

## Understanding VirtualService

VirtualService defines:
- **Routing rules**: How requests are routed to services
- **Match conditions**: Headers, URI, method, authority
- **Destinations**: Which service versions to route to
- **Traffic weights**: For gradual deployments
- **Request transformations**: Headers, URI rewrites

## Deploy Service Versions

Deploy multiple versions of the reviews service:

```bash
kubectl apply -f /tmp/bookinfo.yaml
```{{exec}}

Verify all service versions are running:

```bash
kubectl get pods -l app=reviews
kubectl get services -l app=reviews
```{{exec}}

## Basic VirtualService Routing

Apply a basic VirtualService for routing:

```bash
kubectl apply -f /tmp/virtual-service-routing.yaml
```{{exec}}

View the VirtualService configuration:

```bash
kubectl get virtualservice reviews -o yaml
```{{exec}}

## Test Header-Based Routing

Test routing based on HTTP headers (user identity):

```bash
# Test as Jason (should go to reviews v2)
curl -s "http://$GATEWAY_URL/productpage" -H "end-user: jason" | grep -A 10 "reviews"

# Test as anonymous (should go to reviews v1)
curl -s "http://$GATEWAY_URL/productpage" | grep -A 10 "reviews"
```{{exec}}

## Configure URI-Based Routing

Create a VirtualService with path-based routing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo-uri-routing
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        prefix: "/api/v1"
    rewrite:
      uri: "/api/v1"
    route:
    - destination:
        host: reviews
        subset: v2
  - match:
    - uri:
        prefix: "/api/v2"
    route:
    - destination:
        host: reviews
        subset: v3
  - route:
    - destination:
        host: productpage
EOF
```{{exec}}

## Test Method-Based Routing

Configure routing based on HTTP methods:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: method-routing
spec:
  hosts:
  - httpbin
  http:
  - match:
    - method:
        exact: GET
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
  - match:
    - method:
        exact: POST
    fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 2s
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```{{exec}}

## Configure Request Transformation

Apply header manipulation and URI rewriting:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: transformation
spec:
  hosts:
  - httpbin
  http:
  - match:
    - uri:
        prefix: "/delay"
    rewrite:
      uri: "/delay/5"
    headers:
      request:
        add:
          x-custom-header: "added-by-istio"
        set:
          x-forwarded-proto: "https"
      response:
        add:
          x-response-source: "istio-mesh"
    route:
    - destination:
        host: httpbin
EOF
```{{exec}}

## Test Transformation

Test the request transformation:

```bash
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl -s -I http://httpbin:8000/delay
```{{exec}}

## Analyze Routing Configuration

Use istioctl to analyze your routing:

```bash
istioctl analyze
istioctl proxy-config route $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')
```{{exec}}

## Test Complex Routing

Test multiple routing conditions:

```bash
# Test with specific user agent
curl -s "http://$GATEWAY_URL/productpage" -H "User-Agent: mobile" -H "end-user: jason"

# Test with query parameters
curl -s "http://$GATEWAY_URL/productpage?version=v2"
```{{exec}}

## Debugging Routing Issues

Check routing status and troubleshoot:

```bash
# View effective routing configuration
kubectl get virtualservice -o yaml

# Check proxy configuration
istioctl proxy-status

# Verify listener configuration
istioctl proxy-config listener $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')
```{{exec}}

## Key Takeaways

- VirtualServices define sophisticated routing rules
- Support header, URI, method, and query parameter matching
- Enable request/response transformation
- Work with Gateways for complete traffic management
- Use istioctl for configuration validation and debugging

In the next step, you'll learn about DestinationRule policies for load balancing and service subsets.