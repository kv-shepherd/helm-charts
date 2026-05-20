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

## Bundled PostgreSQL Storage

The bundled PostgreSQL 18 install is intended for evaluation and small
single-cluster installs. Persistent PostgreSQL requires a StorageClass:

```bash
helm repo add shepherd https://kv-shepherd.github.io/helm-charts
helm repo update
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set postgresql.persistence.storageClassName=<storage-class> \
  --wait
```

If `postgresql.persistence.storageClassName` is empty, Kubernetes uses the
cluster default StorageClass. On clusters without a default StorageClass, the
PostgreSQL PVC will stay pending until a StorageClass is selected.

For temporary evaluation installs only, disable persistence:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set postgresql.persistence.enabled=false \
  --wait
```

That uses an `emptyDir` volume. PostgreSQL data can be lost when the Pod is
deleted, evicted, or rescheduled, so this mode is not recommended for
production.

The chart runs a bootstrap seed Job by default. It creates the built-in roles
and the first `admin / admin` account with forced password change. Set
`bootstrapSeed.enabled=false` only when you seed the database outside Helm.

Production installs should prefer an external PostgreSQL 18 service and stable
secrets:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set publicBaseUrl=https://shepherd.example.com \
  --set postgresql.enabled=false \
  --set-string database.url='<postgres-18-dsn>' \
  --set-string security.sessionSecret='<stable-session-secret>' \
  --set-string security.encryptionKey='<64-character-hex-key>' \
  --wait
```

Enable ingress when the cluster has an ingress controller:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=shepherd.example.com \
  --set postgresql.enabled=false \
  --set-string database.url='<postgres-18-dsn>' \
  --set-string security.sessionSecret='<stable-session-secret>' \
  --set-string security.encryptionKey='<64-character-hex-key>' \
  --wait
```

Production installs should provide a certificate from your normal TLS process
and set `ingress.tls` to that Secret. If `ingress.tls` is omitted,
`ingress.selfSigned.enabled=true` lets Helm create an initial self-signed TLS
Secret for bootstrap and evaluation installs.

When ingress is enabled and `publicBaseUrl` is empty, the chart derives it from
the first ingress host. With the default self-signed TLS behavior this becomes
`https://<first-ingress-host>`.

## IP, NodePort, and Port-Forward Access

Ingress and DNS are recommended for production, but they are not required for a
first install. The chart includes an edge proxy that routes `/api` to the
backend and `/` to the web UI, matching the Docker Compose topology. To access
Shepherd through a node IP, expose the edge service as a NodePort:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set edge.service.type=NodePort \
  --set edge.service.nodePorts.https=30443 \
  --set edge.tls.selfSigned.commonName=<node-ip> \
  --set edge.tls.selfSigned.ipAddresses[0]=<node-ip> \
  --set postgresql.persistence.storageClassName=<storage-class> \
  --wait
```

Then open `https://<node-ip>:30443` and accept the bootstrap self-signed
certificate. If `edge.service.nodePorts.https` is omitted, Kubernetes allocates
a port; read it with:

```bash
kubectl -n shepherd get svc shepherd-edge \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}'
```

For local-only access, keep the default `ClusterIP` service and use
port-forwarding:

```bash
kubectl -n shepherd port-forward svc/shepherd-edge 3443:443
```

Then open `https://127.0.0.1:3443`. External OIDC/LDAP callback flows need a
stable externally reachable `publicBaseUrl`; plain IP or port-forward access is
best kept for evaluation and internal testing.

`publicBaseUrl` is optional for basic IP access. Set it to
`https://<node-ip>:<node-port>` when you want stable browser-facing redirects or
external auth callbacks.

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
helm upgrade --install shepherd shepherd/shepherd \
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
`global.imageRepositoryPrefix`, `global.imageTag`, and the per-component image
repository. The public defaults use Docker Hub and the chart `appVersion`
unless a tag is set globally or per component:

```yaml
global:
  imageRegistry: docker.io
  imageRepositoryPrefix: kvshepherd
  imageTag: ""
server:
  image:
    repository: shepherd-server
web:
  image:
    repository: shepherd-web
```

## Publishing

Helm does not host project charts on `helm.sh`. Publish this chart through an
index.yaml-based chart repository such as GitHub Pages. Artifact Hub can index
that repository after ownership metadata is configured.

Before public listing, prepare:

- a released chart package with a SemVer `version`
- matching Shepherd container images for the documented default tag
- public chart storage
- an Artifact Hub publisher account or organization
- `artifacthub-repo.yml` metadata for ownership/verified publisher
- optional provenance or Sigstore signing for release integrity
