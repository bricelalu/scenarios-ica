# Installing Istio with Helm

Helm provides an alternative installation method that's particularly useful in GitOps workflows and environments that already standardized on Helm. This is a key ICA competency for understanding different installation approaches.

## Why Use Helm for Istio Installation?

- **GitOps Integration**: Easier to manage with ArgoCD, Flux, etc.
- **Versioned Releases**: Track and rollback installations
- **Template Flexibility**: Customize installations with values files
- **Enterprise Standards**: Many organizations standardize on Helm

## Verify Helm Installation

Helm was installed during the environment setup:

```plain
helm version
```{{exec}}

## Add Istio Helm Repository

First, add the official Istio Helm repository:

```plain
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```{{exec}}

## Explore Available Istio Charts

List the available Istio Helm charts:

```plain
helm search repo istio
```{{exec}}

## Understanding Istio Helm Chart Structure

Istio uses multiple Helm charts:
- **istio/base**: CRDs and cluster roles
- **istio/istiod**: Control plane (Pilot, Citadel, Galley)
- **istio/gateway**: Ingress and egress gateways

## Install Istio Base Components

Start with the base components (CRDs and cluster-level resources):

```plain
helm install istio-base istio/base -n istio-system --create-namespace
```{{exec}}

Verify base installation:

```plain
kubectl get crds | grep istio
```{{exec}}

## Install Istio Control Plane (istiod)

Install the Istio control plane using our custom values:

```plain
helm install istiod istio/istiod -n istio-system --values /tmp/helm-values.yaml --wait
```{{exec}}

## Verify Control Plane Installation

Check that istiod is running:

```plain
kubectl get pods -n istio-system
```{{exec}}

```plain
kubectl get svc -n istio-system
```{{exec}}

## Install Istio Ingress Gateway

Install the ingress gateway for external traffic:

```plain
helm install istio-ingressgateway istio/gateway -n istio-system --set labels.app=istio-ingressgateway --set service.type=NodePort
```{{exec}}

## Install Istio Egress Gateway

Install the egress gateway for controlled outbound traffic:

```plain
helm install istio-egressgateway istio/gateway -n istio-system --set labels.app=istio-egressgateway --set service.type=ClusterIP --set service.ports[0].port=80 --set service.ports[0].name=http2 --set service.ports[0].targetPort=8080
```{{exec}}

## Verify Complete Helm Installation

Check all Helm releases:

```plain
helm list -n istio-system
```{{exec}}

Verify all components are running:

```plain
kubectl get pods -n istio-system
```{{exec}}

## Compare Helm vs istioctl Installation

Let's compare what we have now versus the istioctl installation from Step 1:

```plain
# Check if previous istioctl installation exists
kubectl get pods -n istio-system -l app=istiod
```{{exec}}

## Test the Helm-based Installation

Let's verify the installation works by enabling sidecar injection and deploying a test application:

```plain
kubectl label namespace default istio-injection=enabled
```{{exec}}

Deploy a test application:

```plain
kubectl apply -f /tmp/bookinfo.yaml
```{{exec}}

Wait for the application to be ready:

```plain
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
```{{exec}}

## Verify Sidecar Injection

Check that sidecars were injected:

```plain
kubectl get pods -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
```{{exec}}

## Helm Installation Management

### View Helm Values

See what values were used for installation:

```plain
helm get values istiod -n istio-system
```{{exec}}

### View Installation Status

Check the status of Helm releases:

```plain
helm status istiod -n istio-system
```{{exec}}

### View Installation History

See the revision history:

```plain
helm history istiod -n istio-system
```{{exec}}

## Customizing Helm Installation

### Upgrade with Different Values

You can upgrade the installation with new values:

```plain
# This is an example - don't run in this scenario
# helm upgrade istiod istio/istiod -n istio-system --values /tmp/new-values.yaml
```

### Rollback to Previous Version

If needed, you can rollback:

```plain
# This is an example - don't run in this scenario  
# helm rollback istiod 1 -n istio-system
```

## Helm vs istioctl Comparison

| Aspect | Helm | istioctl |
|--------|------|----------|
| **Installation** | Multi-chart approach | Single command |
| **Customization** | Values files | IstioOperator CRD |
| **GitOps** | Native support | Requires manifests |
| **Rollback** | Built-in versioning | Manual process |
| **Complexity** | More charts to manage | Simpler single tool |
| **Enterprise** | Fits Helm workflows | Istio-specific |

## Clean Up Test Application

Remove the test application:

```plain
kubectl delete -f /tmp/bookinfo.yaml
kubectl label namespace default istio-injection-
```{{exec}}

## Helm Installation Best Practices

1. **Separate Charts**: Install base, istiod, and gateways separately
2. **Values Files**: Use version-controlled values files
3. **Namespaces**: Always use istio-system namespace
4. **Dependencies**: Install in order: base → istiod → gateways
5. **Monitoring**: Monitor Helm release status

## Troubleshooting Helm Installation

Common issues and solutions:

```plain
# Check Helm release status
helm status istiod -n istio-system

# View installation logs
kubectl logs -n istio-system -l app=istiod

# Validate installation
istioctl analyze --all-namespaces
```

## Key Takeaways

- **Helm installation** uses multiple charts (base, istiod, gateway)
- **Installation order matters**: base → istiod → gateways
- **Values files** provide flexible customization
- **GitOps friendly** for enterprise environments
- **Version management** with rollback capabilities

You now understand both istioctl and Helm installation methods - a key ICA competency!