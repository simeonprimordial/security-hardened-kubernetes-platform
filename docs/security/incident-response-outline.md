# Incident Response Outline

## Scope

This outline covers security incidents affecting the FinServ Digital Kubernetes platform (compromised workload, unexpected egress, policy violation, credential exposure, etc.).

## Detection Sources

- **Falco** — runtime process / file / network anomalies (see `k8s/audit/falco-rules/`)
- **Kubernetes API audit logs** — mutations, anonymous access, secret access metadata
- **NetworkPolicy / Istio** — denied connections and mTLS failures
- **Kyverno** — admission denials (unsigned images, registry violations)
- **Prometheus / Alertmanager** — HPA saturation, error-rate, Falcosidekick alerts

## Response Stages

### 1. Triage
- Confirm signal (Falco rule, audit event, alert)
- Identify namespace, Pod, image, ServiceAccount, and identity
- Check whether the activity is expected (deploy, canary, known job)

### 2. Contain
- Apply emergency isolation NetworkPolicy (block all ingress/egress for the affected namespace or Pod labels)
- Scale down compromised Deployments if needed
- Revoke short-lived Vault leases / rotate dynamic credentials
- Disable or rotate the implicated ServiceAccount / identity group if human access is involved

### 3. Eradicate
- Replace workload with known-good signed image (digest)
- Rotate any potentially exposed secrets via Vault
- Patch admission or NetworkPolicy gaps that allowed the event

### 4. Recover
- Restore traffic gradually (canary first where applicable)
- Confirm probes, mTLS, and metrics are healthy
- Re-enable normal NetworkPolicies only after verification

### 5. Lessons learned
- Update Falco rules, NetworkPolicies, or Kyverno policies
- Document timeline and evidence for compliance
- Feed findings into the platform runbook and onboarding docs

## Key Artefacts in This Repository

| Artefact | Path |
|----------|------|
| Falco custom rules | `k8s/audit/falco-rules/finserv-rules.yaml` |
| Falco values / Alertmanager routing | `k8s/audit/falco-values.yaml` |
| API audit policy | `k8s/audit/audit-policy.yaml` |
| Default-deny NetworkPolicies | `k8s/network-policies/default-deny/` |
| Emergency isolation example | `k8s/audit/emergency-isolation-networkpolicy.yaml` (if present) |

## Principles

- Prefer **identity-scoped** and **short-lived** credentials so blast radius is limited
- Prefer **policy-as-code** fixes over one-off manual changes
- Keep secrets out of audit log bodies and out of Git
