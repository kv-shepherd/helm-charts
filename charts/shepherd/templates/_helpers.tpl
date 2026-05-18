{{/*
Expand the chart name.
*/}}
{{- define "shepherd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "shepherd.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "shepherd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shepherd.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "shepherd.labels" -}}
helm.sh/chart: {{ include "shepherd.chart" . }}
{{ include "shepherd.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: shepherd
{{- end -}}

{{- define "shepherd.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name -}}
{{- end -}}

{{- define "shepherd.componentName" -}}
{{- printf "%s-%s" (include "shepherd.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.componentSelectorLabels" -}}
{{ include "shepherd.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "shepherd.componentLabels" -}}
{{ include "shepherd.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "shepherd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "shepherd.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "shepherd.configName" -}}
{{- printf "%s-config" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.secretName" -}}
{{- default (printf "%s-secret" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-") .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "shepherd.postgresqlName" -}}
{{- printf "%s-postgresql" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.managedClusterAccessName" -}}
{{- printf "%s-managed" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.managedClusterGlobalRoleName" -}}
{{- printf "%s-managed-global" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.managedClusterNamespacedRoleName" -}}
{{- printf "%s-managed-ns" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shepherd.managedClusterServiceAccountName" -}}
{{- default (printf "%s-managed-cluster" (include "shepherd.fullname" .) | trunc 63 | trimSuffix "-") .Values.managedClusterAccess.serviceAccount.name -}}
{{- end -}}

{{- define "shepherd.managedClusterTokenSecretName" -}}
{{- default (printf "%s-token" (include "shepherd.managedClusterServiceAccountName" .) | trunc 63 | trimSuffix "-") .Values.managedClusterAccess.tokenSecret.name -}}
{{- end -}}

{{- define "shepherd.image" -}}
{{- $root := .root -}}
{{- $image := .image -}}
{{- $parts := list -}}
{{- with $root.Values.global.imageRegistry -}}
{{- $parts = append $parts . -}}
{{- end -}}
{{- with $root.Values.global.imageRepositoryPrefix -}}
{{- $parts = append $parts . -}}
{{- end -}}
{{- $parts = append $parts $image.repository -}}
{{- $tag := default (default "latest" $root.Values.global.imageTag) $image.tag -}}
{{- printf "%s:%s" (join "/" $parts) $tag -}}
{{- end -}}
