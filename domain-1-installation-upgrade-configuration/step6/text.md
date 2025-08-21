# Upgrading Istio - Canary and In-Place Strategies

Istio upgrades are critical for maintaining security, performance, and feature updates in production environments. Understanding both canary and in-place upgrade strategies is essential for the ICA exam and production operations.

## Upgrade Strategies Overview

**Canary Upgrade (Recommended)**:
- Install new version alongside current version
- Gradually migrate traffic to new version
- Safe rollback if issues arise
- Zero-downtime upgrades

**In-Place Upgrade**:
- Replace current version directly
- Faster upgrade process
- Some downtime during control plane restart
- Suitable for development environments

## Verify Current Installation

First, let's check our current Istio version:

```plain
istioctl version
```{{exec}}

```plain
kubectl get pods -n istio-system -o wide
```{{exec}}

## Download Multiple Istio Versions

For this scenario, we'll simulate upgrading from one version to another. Let's prepare both versions:

```plain
# Our current version should be 1.26.0
ls -la /root/istio-1.26.0/

# Simulate having an older version to upgrade from
# (In a real scenario, you'd download the target version)
echo "Current version: $(istioctl version --short --remote=false)"
```{{exec}}

## Canary Upgrade Process

### Step 1: Install New Control Plane with Revision

Install a new control plane with a revision label (canary deployment):

```plain
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false --set revision=canary -f /tmp/canary-upgrade-config.yaml -y
```{{exec}}

### Step 2: Verify Both Control Planes Are Running

Check that we now have two control plane deployments:

```plain
kubectl get pods -n istio-system
```{{exec}}

You should see both `istiod` and `istiod-canary` deployments.

### Step 3: Verify Revision Configuration

Check the revision labels:

```plain
kubectl get mutatingwebhookconfiguration
```{{exec}}

```plain
istioctl tag list
```{{exec}}

### Step 4: Deploy Test Application with Current Version

Deploy an application using the current (stable) version:

```plain
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f /tmp/bookinfo.yaml
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
```{{exec}}

### Step 5: Check Current Proxy Version

Verify which control plane version is serving the workloads:

```plain
istioctl proxy-status
```{{exec}}

```plain
kubectl get pods -o custom-columns="NAME:.metadata.name,PROXY_VERSION:.metadata.annotations.sidecar\.istio\.io/proxyImageVersion"
```{{exec}}

### Step 6: Migrate Namespace to Canary Version

Switch the namespace to use the canary control plane:

```plain
kubectl label namespace default istio-injection- istio.io/rev=canary --overwrite
```{{exec}}

### Step 7: Restart Workloads to Use Canary Version

Restart the application to pick up the new control plane:

```plain
kubectl rollout restart deployment productpage-v1
kubectl rollout restart deployment details-v1  
kubectl rollout restart deployment ratings-v1
kubectl rollout restart deployment reviews-v1
kubectl rollout restart deployment reviews-v2
kubectl rollout restart deployment reviews-v3
```{{exec}}

Wait for the rollout to complete:

```plain
kubectl wait --for=condition=Ready pods -l app=productpage --timeout=300s
```{{exec}}

### Step 8: Verify Migration to Canary Version

Check that workloads are now using the canary control plane:

```plain
istioctl proxy-status
```{{exec}}

Test that the application still works:

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
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $SLEEP_POD -- curl -s http://productpage:9080/productpage | grep -o '<title>.*</title>'
```{{exec}}

### Step 9: Validate Canary Deployment

Perform thorough testing of the canary version:

```plain
# Check control plane health
kubectl get pods -n istio-system -l app=istiod

# Run configuration analysis
istioctl analyze --all-namespaces

# Test mTLS connectivity
istioctl authn tls-check $SLEEP_POD productpage.default.svc.cluster.local
```{{exec}}

### Step 10: Complete Canary Upgrade (Remove Old Version)

If the canary version is working correctly, remove the old control plane:

```plain
istioctl uninstall --revision=default -y
```{{exec}}

Wait a moment and check the remaining control plane:

```plain
kubectl get pods -n istio-system
```{{exec}}

### Step 11: Update Default Injection Label

Update the namespace to use the standard injection label:

```plain
kubectl label namespace default istio.io/rev- istio-injection=enabled --overwrite
```{{exec}}

## In-Place Upgrade Process

Let's also demonstrate an in-place upgrade process:

### Step 1: Backup Current Configuration

Always backup before in-place upgrades:

```plain
kubectl get istiooperator -o yaml > istio-backup.yaml 2>/dev/null || echo "No IstioOperator found"
kubectl get configmap istio -n istio-system -o yaml > istio-configmap-backup.yaml 2>/dev/null || echo "No istio configmap found"
```{{exec}}

### Step 2: Perform In-Place Upgrade

Upgrade the current installation directly:

```plain
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -f /tmp/in-place-upgrade-config.yaml -y
```{{exec}}

### Step 3: Monitor Upgrade Progress

Watch the control plane pods during upgrade:

```plain
kubectl get pods -n istio-system -w &
WATCH_PID=$!
sleep 10
kill $WATCH_PID
```{{exec}}

### Step 4: Restart Data Plane (If Required)

For major version upgrades, restart data plane:

```plain
kubectl rollout restart deployment -n default
```{{exec}}

```plain
kubectl wait --for=condition=Ready pods --all --timeout=300s
```{{exec}}

## Rollback Procedures

### Rollback from Canary Upgrade

If issues are discovered during canary upgrade:

```plain
# Switch back to stable version
kubectl label namespace default istio.io/rev- istio-injection=enabled --overwrite

# Restart workloads
kubectl rollout restart deployment --all

# Remove canary version
# istioctl uninstall --revision=canary -y
```

### Rollback from In-Place Upgrade

For in-place upgrades, rollback is more complex:

```plain
# Reinstall previous version (requires previous version binary)
# istioctl install -f istio-backup.yaml -y

# Or restore from backup
echo "In production, you would reinstall the previous version here"
```{{exec}}

## Upgrade Best Practices

### Pre-Upgrade Checklist

```plain
# 1. Backup configurations
kubectl get istiooperator -o yaml > backup/
kubectl get configmap -n istio-system -o yaml > backup/

# 2. Check cluster health
kubectl get nodes
kubectl get pods -n istio-system

# 3. Run pre-upgrade validation
istioctl analyze --all-namespaces

# 4. Test connectivity
echo "Perform connectivity tests here"
```{{exec}}

### During Upgrade

```plain
# Monitor control plane
kubectl get pods -n istio-system

# Monitor proxy status
istioctl proxy-status

# Check for configuration issues
istioctl analyze
```{{exec}}

### Post-Upgrade Validation

```plain
# Verify version
istioctl version

# Test applications
kubectl exec -it $SLEEP_POD -- curl -s http://productpage:9080/productpage | grep -o '<title>.*</title>'

# Check proxy connectivity
istioctl proxy-status

# Validate configuration
istioctl analyze --all-namespaces
```{{exec}}

## Upgrade Troubleshooting

### Common Issues

1. **Control plane pods stuck**: Check resource limits and node capacity
2. **Proxy connection failures**: Verify control plane connectivity
3. **Configuration conflicts**: Run `istioctl analyze`
4. **Application connectivity issues**: Check sidecar injection and restart apps

### Diagnostic Commands

```plain
# Check control plane logs
kubectl logs -n istio-system -l app=istiod

# Check proxy status
istioctl proxy-status

# Analyze configuration
istioctl analyze

# Check proxy configuration
istioctl proxy-config cluster $SLEEP_POD
```{{exec}}

## Clean Up

Remove test applications:

```plain
kubectl delete -f /tmp/bookinfo.yaml
kubectl delete deployment sleep
rm -f istio-backup.yaml istio-configmap-backup.yaml
```{{exec}}

## Upgrade Strategies Comparison

| Aspect | Canary Upgrade | In-Place Upgrade |
|--------|----------------|------------------|
| **Safety** | Very safe, easy rollback | Moderate risk |
| **Downtime** | Zero downtime | Brief control plane downtime |
| **Complexity** | More complex process | Simpler process |
| **Resource Usage** | Temporary double resources | Normal resources |
| **Rollback** | Easy and fast | Complex and slow |
| **Production Use** | Recommended | Development only |

## Key Takeaways

- **Canary upgrades** are safest for production environments
- **Revision labels** enable side-by-side control plane deployment
- **Gradual migration** allows testing before full commitment
- **In-place upgrades** are faster but riskier
- **Backup configurations** before any upgrade
- **Validate thoroughly** after upgrades
- **Monitor** control plane and data plane during upgrades
- **Rollback procedures** are essential for production

Mastering Istio upgrade strategies is crucial for production operations and ICA certification!