# Testing Helm Charts

This repository keeps local validation close to the same shape used in CI.

## Local Render Checks

```bash
make validate
```

The target runs:

- `helm lint charts/shepherd`
- default chart render with bundled PostgreSQL 18
- external PostgreSQL render with Ingress enabled
- registry override render for release image path checks
- managed cluster RBAC render with selected namespace binding
- Prometheus Operator monitoring render with `ServiceMonitor` and
  `PrometheusRule`
- observability render gate for default-off CRDs, server env, scrape endpoint,
  rule counts, and Prometheus template escaping

The Makefile runs Helm through `alpine/helm:3.19.0`.

## Registry Override Render

Use this path to test alternate registries without changing tracked values:

```bash
make template-registry \
  IMAGE_REGISTRY=registry.example.com \
  IMAGE_REPOSITORY_PREFIX=team/shepherd \
  IMAGE_TAG=latest
```

The public defaults remain:

- `docker.io/kvshepherd/shepherd-server`
- `docker.io/kvshepherd/shepherd-web`

## Managed Cluster Access Render

```bash
make template-managed-access
```

This render enables `managedClusterAccess.enabled=true` and verifies the
selected-namespace RoleBinding path. The default managed-cluster mode binds VM
permissions across all namespaces so Shepherd can create namespaces before VM
creation.

## Monitoring Render

```bash
make template-monitoring
```

This render enables `observability.serviceMonitor.enabled=true` and
`observability.prometheusRule.enabled=true`. It verifies that the chart can
render Prometheus Operator resources without installing the Prometheus Operator
CRDs locally.

```bash
make check-observability
```

This gate renders the default chart and the monitoring-enabled chart, then
checks the observability-specific resource contract. `make validate` includes
this gate.

## Server-Side Dry Run

For a Kubernetes API compatibility check without creating resources:

```bash
make template-registry \
  IMAGE_REGISTRY=registry.example.com \
  IMAGE_REPOSITORY_PREFIX=team/shepherd

kubectl apply --dry-run=server -f /tmp/shepherd-helm-registry-render.yaml
```

If you need to validate Namespace creation separately:

```bash
kubectl create namespace shepherd --dry-run=server -o yaml
```

Server-side dry-run does not persist the Namespace object, so validating a
brand-new namespace and the namespaced resources may need two separate dry-run
steps unless the namespace already exists.

## Package Check

```bash
make package
```

The packaged chart is written under `dist/`, which is ignored by git.
