# Network Flow Overview

## Design Principle

Every application namespace starts with a **default-deny** NetworkPolicy (both Ingress and Egress). Approved paths are then added as explicit allow rules derived from the service dependency map.

This produces a zero-trust posture inside the cluster: no Pod can talk to another Pod unless a policy explicitly permits it.

## Application Domains

| Namespace | Domain | Typical data classification |
|-----------|--------|-----------------------------|
| `payments` | Payments | Cardholder data (PCI scope) |
| `risk-compliance` | Risk & Compliance | Regulated |
| `customer` | Customer | PII |
| `platform` | Platform | Internal |

System namespaces (`monitoring`, `security-tools`, `ingress-system`) also start from default-deny and receive only the minimal allows required for their function.

## Payments Domain Flows (example)

**Egress**

- `payment-gateway` → `transaction-processor` (8443)
- `payment-gateway` → `fraud-detection-engine` in risk-compliance (8443)
- `payment-gateway` → `notification-service` in customer (8443)
- `payment-gateway` → external payment provider CIDR `203.0.113.0/28` (443)
- `transaction-processor` → `settlement-engine`, risk-scoring, audit-log-aggregator
- `settlement-engine` → compliance-reporting, audit-log-aggregator
- `refund-service` → transaction-processor, notification-service, audit-log-aggregator
- `recurring-payments-scheduler` → payment-gateway, notification-service

**Ingress**

- `transaction-processor` accepts only from payment-gateway and refund-service
- `settlement-engine` accepts only from transaction-processor
- `payment-gateway` accepts from recurring-payments-scheduler and platform `api-gateway`

DNS egress to `kube-dns` is permitted for all workloads that need name resolution.

## Cross-Domain Rules

Cross-domain traffic is always expressed with both a `namespaceSelector` (domain label) and a `podSelector` (service name). Broad “allow everything from namespace X” rules are avoided.

## Operational Notes

- Default-deny policies live under `k8s/network-policies/default-deny/`
- Domain allow rules live under `k8s/network-policies/allow-rules/<domain>/`
- Helm chart NetworkPolicy templates can emit per-service rules when values are provided
- Emergency isolation NetworkPolicy templates can be applied during incident response to cut traffic quickly
