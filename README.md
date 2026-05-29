# KubeVirt Shepherd Helm Charts

Kubernetes-native Helm charts for KubeVirt Shepherd.

## Charts

| Chart | Description |
|-------|-------------|
| [`shepherd`](charts/shepherd) | KubeVirt Shepherd server, web UI, services, optional ingress, optional Prometheus Operator monitoring resources, and optional PostgreSQL 18 StatefulSet |

## Quick Start

Add the chart repository once:

```bash
helm repo add shepherd https://kv-shepherd.github.io/helm-charts
helm repo update
```

Demo install with temporary PostgreSQL storage and local port-forward:

```bash
helm upgrade --install shepherd shepherd/shepherd \
  --namespace shepherd --create-namespace \
  --set postgresql.persistence.enabled=false

kubectl -n shepherd port-forward svc/shepherd-edge 3443:443
```

Open `https://127.0.0.1:3443`. This mode uses an `emptyDir` database volume;
data can be lost when the PostgreSQL Pod is deleted, evicted, or rescheduled.

Small-cluster install without an Ingress controller:

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
```

Open `https://${NODE_IP}:30443`.

Install with an Ingress controller and your own TLS certificate:

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

First login is `admin / admin`; change the password immediately.

Check rollout status when needed:

```bash
kubectl -n shepherd get pods
helm -n shepherd status shepherd
```

See [`charts/shepherd`](charts/shepherd) for chart values and
[docs/MANAGED_CLUSTER_RBAC.md](docs/MANAGED_CLUSTER_RBAC.md) for managed-cluster
RBAC and kubeconfig creation. The chart README also documents the optional
`ServiceMonitor` and `PrometheusRule` resources for Prometheus Operator-based
monitoring. See [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) for the
observability value contract and render gate.

For local chart development before publishing, replace `shepherd/shepherd` with
`./charts/shepherd`.

## Development

```bash
make validate
make check-observability
make package
```

See [docs/TESTING.md](docs/TESTING.md) for render, registry override,
monitoring, and server-side dry-run examples.
