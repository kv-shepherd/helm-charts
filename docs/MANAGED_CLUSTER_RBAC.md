# Managed Cluster RBAC

Shepherd should not store an admin kubeconfig for routine cluster management.
Use a dedicated Kubernetes ServiceAccount with the smallest permission set that
matches Shepherd's current KubeVirt provider behavior.

## What The Chart Can Create

Enable managed cluster access when you want the chart to render the RBAC and
ServiceAccount manifests for a cluster that Shepherd should manage:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  --set managedClusterAccess.enabled=true
```

This renders:

- a dedicated ServiceAccount in the Shepherd release namespace
- a cluster-level ClusterRole for health checks, Namespace provisioning, Node
  placement enrichment, StorageClass reads, CDI StorageProfile reads, and
  SelfSubjectAccessReview
- a namespaced ClusterRole for KubeVirt VM operations, VMI reads, console/VNC,
  CDI DataVolume observability, PVC/Pod/Event reads, and CDI clone source checks
- either a ClusterRoleBinding for all namespaces or RoleBindings for selected
  namespaces

For a user-reviewed manifest flow, render only this template and apply it to
the target cluster yourself:

```bash
helm template shepherd ./charts/shepherd \
  --namespace shepherd \
  --show-only templates/managed-cluster-access.yaml \
  --set managedClusterAccess.enabled=true \
  --set managedClusterAccess.tokenSecret.create=true \
  > shepherd-managed-cluster-access.yaml

kubectl apply -f shepherd-managed-cluster-access.yaml
```

By default, the namespaced role is bound across all namespaces because Shepherd
creates target namespaces before VM creation. To restrict VM management to
pre-created namespaces, disable the all-namespace binding and list the target
namespaces:

```bash
helm template shepherd ./charts/shepherd \
  --namespace shepherd \
  --set managedClusterAccess.enabled=true \
  --set managedClusterAccess.rbac.namespaced.grantAllNamespaces=false \
  --set 'managedClusterAccess.rbac.namespaced.targetNamespaces[0]=shepherd-workloads'
```

In restricted mode, Shepherd can still perform cluster health checks, but VM
operations only work in namespaces that have a RoleBinding. Namespace creation
still requires cluster-level `namespaces` permissions; remove that rule only if
the application flow is changed to stop calling namespace provisioning.

## Kubeconfig For Import

Kubernetes TokenRequest tokens are preferred for short-lived validation:

```bash
NS=shepherd
SA=shepherd-managed-cluster
TOKEN="$(kubectl -n "$NS" create token "$SA" --duration=24h)"
```

For Shepherd's current stored-kubeconfig import flow, the credential must remain
valid after import. If your environment does not provide a renewable external
identity, opt in to a ServiceAccount token Secret and handle it as a static
cluster credential:

```bash
helm upgrade --install shepherd ./charts/shepherd \
  --namespace shepherd --create-namespace \
  --set managedClusterAccess.enabled=true \
  --set managedClusterAccess.tokenSecret.create=true

TOKEN="$(
  kubectl -n shepherd get secret shepherd-managed-cluster-token \
    -o jsonpath='{.data.token}' | base64 -d
)"
```

Build a kubeconfig from the active cluster endpoint, CA data, and token:

```bash
CLUSTER_NAME="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
SERVER="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA_DATA="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

cat > /tmp/shepherd-managed-cluster.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    server: ${SERVER}
    certificate-authority-data: ${CA_DATA}
users:
- name: shepherd-managed-cluster
  user:
    token: ${TOKEN}
contexts:
- name: shepherd-managed-cluster
  context:
    cluster: ${CLUSTER_NAME}
    user: shepherd-managed-cluster
current-context: shepherd-managed-cluster
EOF
```

Import that kubeconfig into Shepherd instead of an admin kubeconfig.

## Admin Kubeconfig

The chart intentionally does not accept an admin kubeconfig, create credentials
from it, or remove admin access from Shepherd later. That would be intrusive to
the target cluster and belongs to an explicit operator-controlled workflow.

For production, create and import the dedicated Shepherd kubeconfig described
above. For non-production evaluation, importing an admin kubeconfig can be
convenient, but it is not recommended for production because Shepherd would
store broad cluster privileges.

## Current Permission Set

The default managed-cluster RBAC follows the current provider calls:

- `kubevirt.io/virtualmachines`: `get`, `list`, `create`, `patch`, `delete`
- `subresources.kubevirt.io/virtualmachines/start`, `stop`, `restart`:
  `update`
- `kubevirt.io/virtualmachineinstances`: `get`, `list`
- `subresources.kubevirt.io/virtualmachineinstances/console`, `vnc`: `get`
- `subresources.kubevirt.io/virtualmachineinstances/pause`, `unpause`:
  `update`
- core `persistentvolumeclaims`: `get`
- core `pods`, `events`: `list`
- core `namespaces`: `get`, `create`, `patch`
- core `nodes`: `get`, `list`
- `storage.k8s.io/storageclasses`: `get`, `list`
- `cdi.kubevirt.io/datavolumes`: `get`
- `cdi.kubevirt.io/datavolumes/source`: `create`
- `cdi.kubevirt.io/storageprofiles`: `get`
- `authorization.k8s.io/selfsubjectaccessreviews`: `create`
- `kubevirt.io/kubevirts`: `get`
