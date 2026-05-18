# Shepherd Chart

This chart deploys KubeVirt Shepherd with:

- Go API server Deployment and Service
- Next.js web Deployment and Service
- Kubernetes Secret and ConfigMap for runtime configuration
- optional Ingress that routes `/api` to the server and `/` to the web UI
- optional Namespace rendering for GitOps/static manifest workflows
- optional namespace-scoped or cluster-scoped RBAC binding
- optional managed-cluster ServiceAccount and least-privilege RBAC
- optional PostgreSQL 18 StatefulSet for evaluation installs

Production installs should prefer an external PostgreSQL 18 service and stable
secrets:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  --set publicBaseUrl=https://shepherd.example.com \
  --set postgresql.enabled=false \
  --set-string database.url='<postgres-18-dsn>' \
  --set-string security.sessionSecret='<stable-session-secret>' \
  --set-string security.encryptionKey='<64-character-hex-key>'
```

Enable ingress when the cluster has an ingress controller:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=shepherd.example.com \
  --set publicBaseUrl=https://shepherd.example.com \
  --set postgresql.enabled=false \
  --set-string database.url='<postgres-18-dsn>' \
  --set-string security.sessionSecret='<stable-session-secret>' \
  --set-string security.encryptionKey='<64-character-hex-key>'
```

Generated secrets are acceptable for evaluation, but production installs should
set `security.sessionSecret` and `security.encryptionKey`, or use
`secrets.existingSecret`. When the chart creates the Secret, existing generated
values are reused on later Helm upgrades.

Use `--namespace shepherd --create-namespace` for the normal Helm install path.
Set `namespace.create=true` only when you need the rendered manifests to include
the Namespace object, such as with `helm template | kubectl apply`.

RBAC is opt-in and disabled by default because Shepherd usually uses stored
kubeconfigs for managed clusters rather than the release ServiceAccount. If you
need in-cluster API permissions, set `rbac.create=true`,
`serviceAccount.automount=true`, and provide the exact namespace-scoped
`rbac.rules` required by your environment. Use `rbac.clusterWide=true` only for
deliberate cluster-wide installations.

For clusters managed by Shepherd, prefer a dedicated managed-cluster
ServiceAccount and kubeconfig:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  --set managedClusterAccess.enabled=true
```

The managed-cluster RBAC is separate from the release ServiceAccount. It covers
the current KubeVirt provider operations and can bind VM permissions to all
namespaces or only selected namespaces. Non-production environments may import
an admin kubeconfig for convenience, but that is not recommended for production.
See
[`docs/MANAGED_CLUSTER_RBAC.md`](../../docs/MANAGED_CLUSTER_RBAC.md).

When `secrets.existingSecret` is set, the Secret must contain:

- `DATABASE_URL`
- `SECURITY_SESSION_SECRET`
- `SECURITY_ENCRYPTION_KEY`
- `POSTGRES_PASSWORD` when `postgresql.enabled=true`

Image references are assembled from `global.imageRegistry`,
`global.imageRepositoryPrefix`, and the per-component image repository:

```yaml
global:
  imageRegistry: ghcr.io
  imageRepositoryPrefix: kv-shepherd
server:
  image:
    repository: shepherd-server
web:
  image:
    repository: shepherd-web
```
