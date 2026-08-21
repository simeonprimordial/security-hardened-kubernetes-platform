# RBAC Matrix

## Objective

FinServ Digital uses Kubernetes RBAC to enforce least privilege across platform personas. Human access is represented by identity-provider groups. Workload identities use Kubernetes ServiceAccounts and are bound only to the namespaces they require.

## Persona Matrix

| Capability | Platform Administrator | Namespace Administrator | Developer — Dev/Staging | Developer — Production | CI/CD Service Account | Security Auditor | Monitoring Service Account |
|---|---|---|---|---|---|---|---|
| View Pods | All namespaces | Own namespace | Own namespace | Own namespace | No direct need | All namespaces | All namespaces |
| View Pod logs | All namespaces | Own namespace | Own namespace | Own namespace | No | All namespaces | No |
| Exec into Pods | Yes | Own namespace | Own namespace | **No** | No | No | No |
| Create/update Deployments | All | Own namespace | No | No | Bound namespace only | No | No |
| Delete Deployments | All | Own namespace | No | No | No | No | No |
| Manage Services | All | Own namespace | Read only | Read only | Create/update/patch | Read only | Read only |
| Manage ConfigMaps | All | Own namespace | No | No | Create/update/patch | Read only | **No** |
| Read Secrets | All | Own namespace | **No** | **No** | **No** | **No** | **No** |
| Modify Secrets | All | Own namespace | No | No | No | No | No |
| Manage NetworkPolicies | All | Own namespace | No | No | No | Read only | No |
| Manage RBAC | Cluster-wide | No cluster RBAC | No | No | No | Read only | No |
| Create/delete Namespaces | Yes | No | No | No | No | No | No |
| Read cluster security posture | Yes | Namespace only | No | No | No | Yes | Metrics/status only |
| Read metrics endpoints | Yes | Namespace resources | Limited | Limited | No | Read only where exposed | Yes |

## Environment Difference for Developers

- Development and staging allow controlled `pods/exec` for debugging.
- Production omits `pods/exec` entirely.
- Both variants allow Pod log reads.
- Neither role grants read or write access to Secrets.

## CI/CD Least Privilege

Each application namespace has a `cicd-deployer` ServiceAccount bound to a namespace-scoped Role. It can create/update/patch Deployments, Services, ConfigMaps, HPAs, and PodDisruptionBudgets.

It intentionally cannot:

- read or modify Secrets
- exec into Pods
- create arbitrary ServiceAccounts or RBAC rules
- delete Deployments
- deploy into another namespace unless a separate RoleBinding is explicitly created there

Production pipelines should authenticate using short-lived credentials / workload identity rather than storing long-lived service-account tokens.

## Security Auditor

The `finserv-security-auditor` ClusterRole grants `get`, `list`, and `watch` on platform resources needed for evidence review, including RBAC and NetworkPolicies. The role intentionally excludes Secrets.

## Identity Groups

| Domain | Admin Group | Developer Group |
|---|---|---|
| Payments | `finserv:payments:admins` | `finserv:payments:developers` |
| Risk & Compliance | `finserv:risk:admins` | `finserv:risk:developers` |
| Customer | `finserv:customer:admins` | `finserv:customer:developers` |
| Platform | `finserv:platform:admins` | `finserv:platform:developers` |

Cluster-scoped groups:

- `finserv:platform:cluster-admins`
- `finserv:security:auditors`

## Manifest Application Model

```bash
kubectl apply -f k8s/rbac/roles/namespace-administrators.yaml
kubectl apply -f k8s/rbac/roles/cicd-deployers.yaml
kubectl apply -f k8s/rbac/roles/developers-prod.yaml   # or developers-nonprod in lower envs
kubectl apply -f k8s/rbac/clusterroles/
kubectl apply -f k8s/rbac/rolebindings/team-bindings.yaml
```

Do not apply both developer role variants to the same cluster — they intentionally define the same Role names with different permissions.
