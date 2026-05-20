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

## Add The Repository

```bash
helm repo add shepherd https://kv-shepherd.github.io/helm-charts
helm repo update
```

## Demo Install

Use this path for a quick trial. It does not require an Ingress controller or a
StorageClass:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set postgresql.persistence.enabled=false

kubectl -n shepherd port-forward svc/shepherd-edge 3443:443
```

Open `https://127.0.0.1:3443` and accept the bootstrap self-signed certificate.
This mode uses an `emptyDir` database volume. Data can be lost when the
PostgreSQL Pod is deleted, evicted, or rescheduled.

## NodePort Install

Use this path for small clusters or lab environments without an Ingress
controller:

```bash
STORAGE_CLASS=standard
NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"

helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set edge.service.type=NodePort \
  --set edge.service.nodePorts.https=30443 \
  --set "edge.tls.selfSigned.commonName=${NODE_IP}" \
  --set "edge.tls.selfSigned.ipAddresses[0]=${NODE_IP}" \
  --set "postgresql.persistence.storageClassName=${STORAGE_CLASS}"

echo "https://${NODE_IP}:30443"
```

## Ingress With TLS

Use this path when the cluster has an Ingress controller and you already have a
certificate:

```bash
SHEPHERD_HOST=shepherd.example.com
STORAGE_CLASS=standard

kubectl create namespace shepherd --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shepherd create secret tls shepherd-tls \
  --cert ./tls.crt \
  --key ./tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=${SHEPHERD_HOST}" \
  --set "ingress.tls[0].secretName=shepherd-tls" \
  --set "ingress.tls[0].hosts[0]=${SHEPHERD_HOST}" \
  --set "postgresql.persistence.storageClassName=${STORAGE_CLASS}"
```

For bootstrap installs without a certificate, omit `ingress.tls`. The chart
creates a self-signed ingress certificate by default:

```bash
SHEPHERD_HOST=shepherd.example.com
STORAGE_CLASS=standard

helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=${SHEPHERD_HOST}" \
  --set "postgresql.persistence.storageClassName=${STORAGE_CLASS}"
```

When ingress is enabled and `publicBaseUrl` is empty, the chart derives it from
the first ingress host.

## External PostgreSQL

Use a PostgreSQL 18 service and stable secrets for production installs:

```bash
SHEPHERD_HOST=shepherd.example.com
POSTGRES_DSN='postgres://shepherd:change-me@postgres.example.com:5432/shepherd_db?sslmode=require'
SESSION_SECRET="$(openssl rand -base64 48)"
ENCRYPTION_KEY="$(openssl rand -hex 32)"

helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set "publicBaseUrl=https://${SHEPHERD_HOST}" \
  --set postgresql.enabled=false \
  --set-string "database.url=${POSTGRES_DSN}" \
  --set-string "security.sessionSecret=${SESSION_SECRET}" \
  --set-string "security.encryptionKey=${ENCRYPTION_KEY}"
```

## Persistent Bundled PostgreSQL

The bundled PostgreSQL 18 install is intended for evaluation and small
single-cluster installs. Persistent PostgreSQL requires a StorageClass:

```bash
STORAGE_CLASS=standard

helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set "postgresql.persistence.storageClassName=${STORAGE_CLASS}"
```

If `postgresql.persistence.storageClassName` is empty, Kubernetes uses the
cluster default StorageClass. On clusters without a default StorageClass, the
PostgreSQL PVC will stay pending until a StorageClass is selected.

## Verify

```bash
kubectl -n shepherd get pods
helm -n shepherd status shepherd
```

Add `--wait` to `helm upgrade --install` in CI or scripts when the command
should block until rendered resources are ready. It is intentionally omitted
from the copy-first examples above.

## Operational Notes

The chart runs a bootstrap seed Job by default. It creates the built-in roles
and the first `admin / admin` account with forced password change. Set
`bootstrapSeed.enabled=false` only when you seed the database outside Helm.

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
