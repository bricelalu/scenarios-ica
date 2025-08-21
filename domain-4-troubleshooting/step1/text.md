# Troubleshooting Configuration

The first step in troubleshooting Istio is validating your configuration. Istio provides powerful tools to analyze and validate configurations before they cause issues in production.

## Essential Configuration Troubleshooting Tools

Let's start by exploring the primary configuration troubleshooting commands:

```plain
istioctl version
```{{exec}}

```plain
kubectl get pods -n istio-system
```{{exec}}

```plain
kubectl get pods -l istio-injection=enabled
```{{exec}}

## Using istioctl analyze

The `istioctl analyze` command is your first line of defense for configuration issues:

```plain
istioctl analyze
```{{exec}}

```plain
istioctl analyze --all-namespaces
```{{exec}}

## Analyzing Specific Resources

Let's look at specific resource analysis:

```plain
istioctl analyze virtualservice
```{{exec}}

```plain
istioctl analyze gateway
```{{exec}}

## Troubleshooting Broken VirtualService

Let's apply a broken VirtualService and learn how to diagnose it:

```plain
kubectl apply -f /tmp/broken-virtualservice.yaml
```{{exec}}

Now analyze the configuration:

```plain
istioctl analyze
```{{exec}}

View the broken configuration:

```plain
kubectl get virtualservice broken-reviews -o yaml
```{{exec}}

## Common VirtualService Issues

Let's identify and fix the issues:

```plain
# Check if the service exists
kubectl get svc reviews
```{{exec}}

```plain
# Check if the destination rule exists
kubectl get destinationrule reviews
```{{exec}}

## Fix the VirtualService

The issue is likely a missing service or incorrect host reference. Let's fix it:

```plain
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: fixed-reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```{{exec}}

Now let's create the missing DestinationRule:

```plain
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
```{{exec}}

## Verify the Fix

```plain
istioctl analyze
```{{exec}}

```plain
kubectl get virtualservice,destinationrule
```{{exec}}

## Configuration Validation Best Practices

1. **Always run istioctl analyze** before applying configurations
2. **Check resource relationships** (VirtualService → DestinationRule → Service)
3. **Validate YAML syntax** and required fields
4. **Use dry-run** to catch issues early: `kubectl apply --dry-run=client`

In the next step, we'll troubleshoot control plane issues!