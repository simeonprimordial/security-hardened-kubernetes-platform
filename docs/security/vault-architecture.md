# Vault Architecture (Summary)

## Goal

Applications never receive plaintext secrets from Git, ConfigMaps, or long-lived Kubernetes Secrets that are broadly readable. Secrets are injected at runtime through HashiCorp Vault using short-lived, audience-scoped identity.

## Flow

1. Workload runs as a dedicated ServiceAccount (`automountServiceAccountToken: false`).
2. A projected ServiceAccount token is mounted with a limited audience (`vault`) and short TTL (e.g. 600s).
3. Vault Agent (sidecar / injector) authenticates to Vault using that token.
4. Vault evaluates a domain-scoped policy (e.g. `payments-prod.hcl`).
5. Authorised material is rendered into the Pod (file or environment) without giving the application a broad Kubernetes API token.

## Policy Model

Policies are organised by **environment + domain**:

- `secret/data/prod/payments/*` — static secrets for Payments
- `database/creds/prod-payments-app` — dynamic database credentials
- `transit/encrypt|decrypt/cardholder-data` — encryption as a service for PCI data

Each domain has its own policy file under `k8s/vault/vault-policies/`.

## What is intentionally denied

- Application containers reading arbitrary Kubernetes Secrets
- Long-lived static tokens in CI or in Git
- Cross-domain secret paths (Payments cannot read Customer secrets, etc.)

## Evidence / operations

- Role and path references appear as annotations on Deployments (`vault.hashicorp.com/role`, `vault.hashicorp.com/agent-inject-secret-*`)
- Policies are versioned in this repository
- Live Vault configuration (auth methods, KMS seal, HA storage) remains a platform responsibility outside pure Git manifests
