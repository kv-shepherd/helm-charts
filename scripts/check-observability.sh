#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_IMAGE="${HELM_IMAGE:-alpine/helm:3.19.0}"

default_render="$(mktemp)"
monitoring_render="$(mktemp)"
trap 'rm -f "${default_render}" "${monitoring_render}"' EXIT

fail() {
  echo "[helm-observability] ERROR: $1" >&2
  exit 1
}

if ! command -v rg >/dev/null 2>&1; then
  rg() {
    local fixed=0
    local quiet=0
    local count=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -F)
          fixed=1
          shift
          ;;
        -q)
          quiet=1
          shift
          ;;
        --count)
          count=1
          shift
          ;;
        --)
          shift
          break
          ;;
        -*)
          echo "fallback rg: unsupported option $1" >&2
          return 2
          ;;
        *)
          break
          ;;
      esac
    done
    local pattern="$1"
    shift
    if [[ "${count}" == "1" ]]; then
      if [[ "${fixed}" == "1" ]]; then
        grep -F -c -- "${pattern}" "$@"
      else
        grep -E -c -- "${pattern}" "$@"
      fi
    elif [[ "${quiet}" == "1" ]]; then
      if [[ "${fixed}" == "1" ]]; then
        grep -F -q -- "${pattern}" "$@"
      else
        grep -E -q -- "${pattern}" "$@"
      fi
    elif [[ "${fixed}" == "1" ]]; then
      grep -F -- "${pattern}" "$@"
    else
      grep -E -- "${pattern}" "$@"
    fi
  }
fi

render_chart() {
  local output_file="$1"
  shift
  docker run --rm -v "${ROOT_DIR}:/work" -w /work "${HELM_IMAGE}" \
    template shepherd charts/shepherd --namespace shepherd "$@" >"${output_file}"
}

require_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  rg -q "${pattern}" "${file}" || fail "${message}"
}

require_literal() {
  local file="$1"
  local text="$2"
  local message="$3"
  rg -F -q "${text}" "${file}" || fail "${message}"
}

require_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local message="$4"
  local count
  count="$(rg --count "${pattern}" "${file}" || true)"
  count="${count:-0}"
  [[ "${count}" == "${expected}" ]] || fail "${message}: got ${count}, want ${expected}"
}

render_chart "${default_render}"
render_chart "${monitoring_render}" \
  --set observability.serviceMonitor.enabled=true \
  --set observability.prometheusRule.enabled=true

for key in \
  OBSERVABILITY_METRICS_ENABLED \
  OBSERVABILITY_METRICS_PATH \
  OBSERVABILITY_DATABASE_METRICS_ENABLED \
  OBSERVABILITY_DATABASE_METRICS_TIMEOUT \
  OBSERVABILITY_RIVER_METRICS_ENABLED \
  OBSERVABILITY_RIVER_METRICS_TIMEOUT \
  OBSERVABILITY_TRACING_ENABLED \
  OBSERVABILITY_TRACING_SERVICE_NAME \
  OBSERVABILITY_TRACING_EXPORTER \
  OBSERVABILITY_TRACING_SAMPLE_RATIO \
  OBSERVABILITY_TRACING_SHUTDOWN_TIMEOUT; do
  require_match "${default_render}" "^[[:space:]]+${key}:" "default render missing ${key}"
  require_match "${monitoring_render}" "^[[:space:]]+${key}:" "monitoring render missing ${key}"
done

if rg -q '^kind: (ServiceMonitor|PrometheusRule)$' "${default_render}"; then
  fail "default render must not include Prometheus Operator resources"
fi

require_count "${monitoring_render}" '^kind: ServiceMonitor$' 1 "monitoring render ServiceMonitor count mismatch"
require_count "${monitoring_render}" '^kind: PrometheusRule$' 1 "monitoring render PrometheusRule count mismatch"

require_match "${monitoring_render}" '^[[:space:]]+path: "/metrics"$' "ServiceMonitor must scrape /metrics"
require_match "${monitoring_render}" '^[[:space:]]+- port: http$' "ServiceMonitor must scrape named http port"
require_match "${monitoring_render}" '^[[:space:]]+scheme: "http"$' "ServiceMonitor must default to http scheme"
require_match "${monitoring_render}" '^[[:space:]]+interval: "30s"$' "ServiceMonitor must default to 30s interval"
require_match "${monitoring_render}" '^[[:space:]]+jobLabel: "app\.kubernetes\.io/name"$' "ServiceMonitor must set a predictable job label"
require_match "${monitoring_render}" '^[[:space:]]+app.kubernetes.io/component: server$' "ServiceMonitor selector must target server component"

require_match "${monitoring_render}" '^[[:space:]]+- name: shepherd\.recording$' "PrometheusRule missing shepherd.recording group"
require_match "${monitoring_render}" '^[[:space:]]+- name: shepherd\.baseline$' "PrometheusRule missing shepherd.baseline group"
require_literal "${monitoring_render}" 'up{job="shepherd"} == 0' "PrometheusRule target-down alert must match the ServiceMonitor job label"
require_count "${monitoring_render}" '^[[:space:]]+- record: shepherd:' 7 "PrometheusRule recording rule count mismatch"
require_count "${monitoring_render}" '^[[:space:]]+- alert: Shepherd' 9 "PrometheusRule alert count mismatch"
# shellcheck disable=SC2016
require_literal "${monitoring_render}" 'phase={{ $labels.phase }} code={{ $labels.code }}' "Prometheus label templates must survive Helm rendering"
# shellcheck disable=SC2016
require_literal "${monitoring_render}" 'queue={{ $labels.queue }}' "Prometheus queue label template must survive Helm rendering"

echo "[helm-observability] OK"
