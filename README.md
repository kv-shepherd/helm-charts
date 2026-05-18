# KubeVirt Shepherd Helm Charts

Kubernetes-native Helm charts for KubeVirt Shepherd.

## Charts

| Chart | Description |
|-------|-------------|
| [`shepherd`](charts/shepherd) | KubeVirt Shepherd server, web UI, services, optional ingress, and optional PostgreSQL 18 StatefulSet |

## Quick Start

Install with the default GHCR images and bundled PostgreSQL 18:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace
```

For production, use an external PostgreSQL 18 database and stable secrets in a
values file:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  -f values.prod.yaml
```

See [`charts/shepherd`](charts/shepherd) for chart values and
[docs/MANAGED_CLUSTER_RBAC.md](docs/MANAGED_CLUSTER_RBAC.md) for managed-cluster
RBAC and kubeconfig creation.

## Development

```bash
make validate
make package
```

See [docs/TESTING.md](docs/TESTING.md) for render, registry override, and
server-side dry-run examples.
