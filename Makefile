.PHONY: lint template template-external template-managed-access template-registry package validate

HELM_IMAGE ?= alpine/helm:3.19.0
IMAGE_REGISTRY ?= ghcr.io
IMAGE_REPOSITORY_PREFIX ?= kv-shepherd
IMAGE_TAG ?= latest

lint:
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) lint charts/shepherd

template:
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) template shepherd charts/shepherd --namespace shepherd >/tmp/shepherd-helm-render.yaml

template-external:
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) template shepherd charts/shepherd --namespace shepherd \
		--set postgresql.enabled=false \
		--set-string database.url='postgres://shepherd:example@postgres.example.com:5432/shepherd_db?sslmode=require' \
		--set-string security.sessionSecret='example-session-secret-with-enough-length' \
		--set-string security.encryptionKey='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
		--set ingress.enabled=true \
		--set 'ingress.hosts[0].host=shepherd.example.com' \
		>/tmp/shepherd-helm-external-render.yaml

template-registry:
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) template shepherd charts/shepherd --namespace shepherd \
		--set global.imageRegistry=$(IMAGE_REGISTRY) \
		--set global.imageRepositoryPrefix=$(IMAGE_REPOSITORY_PREFIX) \
		--set server.image.tag=$(IMAGE_TAG) \
		--set web.image.tag=$(IMAGE_TAG) \
		>/tmp/shepherd-helm-registry-render.yaml

template-managed-access:
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) template shepherd charts/shepherd --namespace shepherd \
		--set managedClusterAccess.enabled=true \
		--set managedClusterAccess.rbac.namespaced.grantAllNamespaces=false \
		--set 'managedClusterAccess.rbac.namespaced.targetNamespaces[0]=shepherd-workloads' \
		>/tmp/shepherd-helm-managed-access-render.yaml

package:
	mkdir -p dist
	docker run --rm -v "$(CURDIR):/work" -w /work $(HELM_IMAGE) package charts/shepherd --destination dist

validate: lint template template-external template-registry template-managed-access
