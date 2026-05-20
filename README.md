# KubeVirt Shepherd Helm Charts

Kubernetes-native Helm charts for KubeVirt Shepherd.

## Charts

| Chart | Description |
|-------|-------------|
| [`shepherd`](charts/shepherd) | KubeVirt Shepherd server, web UI, services, optional ingress, and optional PostgreSQL 18 StatefulSet |

## Quick Start

Install with the published chart, default public images, and bundled
PostgreSQL 18:

```bash
helm repo add shepherd https://kv-shepherd.github.io/helm-charts
helm repo update
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=shepherd.example.com \
  --set postgresql.persistence.storageClassName=<storage-class> \
  --wait
```

When ingress is enabled and `publicBaseUrl` is omitted, the chart derives
`https://<first-ingress-host>` automatically. Set `publicBaseUrl` explicitly
only when the externally visible URL differs from the ingress host.

If you omit `postgresql.persistence.storageClassName`, Kubernetes uses the
cluster's default StorageClass. For evaluation-only installs without persistent
storage, set `postgresql.persistence.enabled=false`; this creates an ephemeral
volume and data can be lost when the PostgreSQL Pod is rescheduled.

When ingress is enabled, provide your normal TLS Secret through `ingress.tls`
for production. If `ingress.tls` is omitted, the chart generates a self-signed
certificate by default so first deploys still come up over HTTPS.

The default install also runs the bootstrap seed Job, creating `admin / admin`
for first login with a forced password change.

For IP-only evaluation without DNS or ingress, expose the chart's HTTPS edge
proxy with `edge.service.type=NodePort`; it routes `/api` and `/` through one
service.

For production, use an external PostgreSQL 18 database and stable secrets in a
values file:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  -f values.prod.yaml
```

See [`charts/shepherd`](charts/shepherd) for chart values and
[docs/MANAGED_CLUSTER_RBAC.md](docs/MANAGED_CLUSTER_RBAC.md) for managed-cluster
RBAC and kubeconfig creation.

For local chart development before publishing, replace `shepherd/shepherd` with
`./charts/shepherd`.

## Development

```bash
make validate
make package
```

See [docs/TESTING.md](docs/TESTING.md) for render, registry override, and
server-side dry-run examples.
