# Final Architecture Overview

## Architecture Summary

FinServ Digital uses **environment-separated Kubernetes clusters** for development, staging, and production. Production is modelled on Amazon EKS and spreads worker capacity across availability zones. Environment separation prevents a development-cluster compromise from sharing the production control-plane boundary.

Inside each environment, application workloads are organised into four domains:

- Payments
- Risk & Compliance
- Customer
- Platform

Every domain starts from default-deny network posture. Approved service paths are derived from the service dependency map and implemented through explicit NetworkPolicies rather than broad intra-cluster trust.

## Defence-in-Depth Layers

### Cloud

- Private-network / managed-Kubernetes reference architecture
- Encrypted storage / KMS design
- Multi-AZ worker capacity
- Controlled ingress and external TLS / WAF boundary
- Enterprise identity / MFA expectations for administrators

### Cluster

- Namespace separation
- Least-privilege RBAC
- Default-deny networking
- Kyverno admission controls
- Kubernetes API audit policy
- ResourceQuota and LimitRange governance
- Istio strict mTLS and workload identity

### Container

- Non-root runtime
- RuntimeDefault seccomp
- No privilege escalation
- Dropped Linux capabilities
- Read-only root filesystem
- Signed / scanned trusted images
- Falco runtime detection

### Code and Delivery

- Reviewed source changes
- Automated tests
- Image vulnerability scanning
- SBOM generation
- Cosign signing / provenance design
- Immutable release references
- Helm lint / render / schema checks
- Staged environment promotion and production canary routing

## Secrets Flow

Applications do not receive plaintext secrets from Git or ConfigMaps. A dedicated workload ServiceAccount obtains a short-lived, audience-scoped projected identity token for Vault Agent authentication. Vault policy scopes access by environment / domain / service and renders authorised runtime secret material into the Pod without granting the application a broadly mounted Kubernetes API token.

## Scale Path

The five Payments services each use an HPA range of 4–20 replicas, giving an aggregate domain range of **20–100 replicas**. Fast scale-up behaviour, namespace quota headroom, Prometheus alerts, and the scale-test dashboard support a five-times burst scenario. The repository documents the configuration and test procedure; an actual measured scaling result still requires a metrics-enabled running cluster and load generator.

## Auditability

The design links controls to evidence through:

- API audit logging
- Falco runtime alerts
- Central monitoring / alert routing
- Image scan / signature evidence
- Git / CI traceability
- PCI-DSS requirement-to-evidence mapping
- Incident-response and operations runbooks

The repository clearly separates **implemented design evidence**, **simulated evidence**, and **live-environment proof** so that planned controls are not represented as production compliance evidence.
