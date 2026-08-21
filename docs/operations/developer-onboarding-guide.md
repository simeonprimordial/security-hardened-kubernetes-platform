# Developer Onboarding Guide

## Objective

This guide is for FinServ Digital developers who can build a container image but may be new to Kubernetes and Helm. A developer should be able to deploy a new non-production service, view logs, debug a Pod, manage non-secret configuration, and request secret access without receiving broad cluster permissions or manually copying credentials.

## 1. Platform Contract

The platform team owns cluster lifecycle, namespaces, baseline NetworkPolicies, RBAC, Vault integration, admission policies, Pod Security, Falco/audit controls, service mesh, monitoring, and the reusable Helm chart.

Application teams own application code, immutable image versions, resource sizing, health endpoints, approved dependencies, non-secret configuration, and service-specific tests.

Developers do not need `cluster-admin` and should never bypass policy controls to make a deployment work.

## 2. Environment and Namespace Model

Development, staging, and production are separate clusters. Each cluster contains the same four application-domain namespaces:

| Domain | Namespace |
|---|---|
| Payments | `payments` |
| Risk & Compliance | `risk-compliance` |
| Customer | `customer` |
| Platform | `platform` |

Before any operation, confirm both context and namespace:

```bash
kubectl config current-context
kubectl get ns
kubectl auth can-i get pods -n <namespace>
```

For production, confirm the context twice and use the approved release workflow rather than manual `kubectl apply`.

## 3. Minimum Tooling

```bash
git --version
kubectl version --client
helm version
```

## 4. Kubernetes Vocabulary You Need

- **Pod** — one running workload instance
- **Deployment** — desired state for replicated application Pods
- **Service** — stable internal endpoint for a workload
- **Namespace** — security/resource boundary for an application domain
- **ConfigMap** — non-secret configuration
- **ServiceAccount** — workload identity inside Kubernetes
- **NetworkPolicy** — allowed network paths for selected Pods
- **HPA** — HorizontalPodAutoscaler that adjusts replica count from metrics
- **Helm** — packages and renders Kubernetes resources from a chart and values

## 5. Deploy a New Service

### Step 1 — Choose the domain

A service must have one owning namespace. RBAC, Vault policy, NetworkPolicy, and audit evidence all depend on that boundary.

### Step 2 — Create service values

Start from the environment file under `helm/` and add service-specific values. Example:

```yaml
domain: payments

image:
  repository: ghcr.io/finserv-digital/payment-gateway
  tag: "1.7.3"

config:
  LOG_LEVEL: info

networkPolicy:
  enabled: true
  ingress:
    - namespace: platform
      podLabels:
        app.kubernetes.io/name: api-gateway
      port: 8080
  egress:
    - namespace: risk-compliance
      podLabels:
        app.kubernetes.io/name: fraud-detection
      port: 8080
```

Do not add `0.0.0.0/0` or broad cross-namespace access to solve a connectivity problem.

### Step 3 — Render before deploying

```bash
helm lint ./helm -f ./helm/values-dev.yaml

helm template payment-gateway ./helm \
  --namespace payments \
  -f ./helm/values-dev.yaml \
  > rendered-payment-gateway.yaml
```

Confirm:

- correct namespace
- immutable image (not `latest`)
- non-root, no privilege escalation, capabilities dropped
- resource requests/limits and probes
- only approved network paths
- no secret values in the YAML

### Step 4 — Deploy to development

```bash
helm upgrade --install payment-gateway ./helm \
  --namespace payments \
  -f ./helm/values-dev.yaml
```

Production deployment is performed by the approved CI/CD path.

### Step 5 — Verify rollout

```bash
kubectl rollout status deployment/<name> -n payments
kubectl get pods,svc,networkpolicy -n payments
```

## 6. View Logs

```bash
kubectl get pods -n payments
kubectl logs -n payments <pod-name> -c application
kubectl logs -n payments <pod-name> -c application --previous   # previous crash
```

Do not request Kubernetes Secret read access just to troubleshoot startup.

## 7. Debug Pods Safely

Development and staging may permit controlled `exec`. Production developer RBAC intentionally does not grant `pods/exec`.

```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl auth can-i create pods/exec -n <namespace>
```

## 8. Configuration vs Secrets

Use Helm values / ConfigMaps only for non-secret settings (log level, timeouts, non-confidential feature flags).

For secrets, enable Vault by **reference only**:

```yaml
vault:
  enabled: true
  role: prod-payments-payment-gateway
  secretPath: secret/data/prod/payments/payment-gateway
  destination: database.env
```

Never store credentials in Git, Dockerfiles, Helm values, ConfigMaps, or tickets.

## 9. Connectivity Troubleshooting

If service A cannot reach service B:

1. Confirm both Pods are healthy
2. Confirm Service selectors/endpoints
3. Inspect NetworkPolicies on both sides
4. Verify service-mesh sidecar status and mTLS policy
5. Request the smallest policy change that represents the legitimate dependency

```bash
kubectl get svc,endpoints,networkpolicy -n <namespace>
kubectl describe networkpolicy -n <namespace> <policy>
```

Do not fix a narrow dependency by removing default-deny controls.

## 10. Developer Safety Rules

- Never request `cluster-admin` for normal development
- Never disable Pod Security, admission control, Falco, mTLS, or NetworkPolicy to force a deployment
- Never use `latest` for a release candidate
- Never remove probes or resource controls to mask instability
- Never copy Vault values into a ConfigMap
- Never broaden a firewall rule when a single source/destination/port is sufficient
- Never perform an unreviewed manual production deployment
