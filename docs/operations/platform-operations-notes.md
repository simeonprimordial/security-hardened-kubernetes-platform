# Platform Operations Notes

## Day-to-day responsibilities

| Area | Platform team |
|------|---------------|
| Clusters | Lifecycle, upgrades, node groups, multi-AZ capacity |
| Namespaces | Create, label (domain, environment, data classification, PSS) |
| Network | Default-deny baseline, review allow-rule PRs |
| Identity | Group → Role bindings, CI ServiceAccounts |
| Secrets | Vault auth methods, domain policies, rotation |
| Admission | Kyverno policies, image trust roots |
| Runtime | Falco rules, audit policy, alert routing |
| Mesh | Istio installation, STRICT mTLS defaults |
| Observability | Prometheus/Grafana/Loki stack, scaling alerts |
| Chart | Maintain reusable hardened Helm chart |

## Useful apply order (new environment)

```bash
# 1. Namespaces + PSS labels
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/pod-security/

# 2. Quotas and limits
kubectl apply -f k8s/resource-quotas/
kubectl apply -f k8s/limit-ranges/

# 3. Network baseline
kubectl apply -f k8s/network-policies/default-deny/
kubectl apply -f k8s/network-policies/allow-rules/
kubectl apply -f k8s/audit/emergency-isolation-networkpolicy.yaml

# 4. RBAC
kubectl apply -f k8s/rbac/

# 5. Mesh
kubectl apply -f k8s/service-mesh/

# 6. Workloads / chart releases
helm upgrade --install <service> ./helm -n <namespace> -f helm/values-<env>.yaml
```

## Incident quick actions

**Quarantine a Pod**

```bash
kubectl label pod <pod> -n <ns> security.finserv.io/quarantine=true
# emergency-quarantine NetworkPolicy already present → all traffic blocked
```

**Scale down a compromised Deployment**

```bash
kubectl scale deployment <name> -n <ns> --replicas=0
```

**Check Falco / audit signals**

- Falco rules: `k8s/audit/falco-rules/finserv-rules.yaml`
- Audit policy: `k8s/audit/audit-policy.yaml`
- Alert path: Falcosidekick → Alertmanager (see `falco-values.yaml`)

## Validation before merge

```bash
bash scripts/validate-manifests.sh
```

CI runs the same path on every push/PR to `main`.
