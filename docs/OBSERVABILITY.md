# Observability Deployment

The Shepherd chart keeps observability aligned with the public Docker Compose
deployment without installing a monitoring stack by default.

## Runtime Configuration

The server ConfigMap renders the same `OBSERVABILITY_*` environment variables
used by the public Compose deployment:

| Value | Environment |
|-------|-------------|
| `observability.metrics.enabled` | `OBSERVABILITY_METRICS_ENABLED` |
| `observability.metrics.path` | `OBSERVABILITY_METRICS_PATH` |
| `observability.metrics.databaseMetricsEnabled` | `OBSERVABILITY_DATABASE_METRICS_ENABLED` |
| `observability.metrics.databaseMetricsTimeout` | `OBSERVABILITY_DATABASE_METRICS_TIMEOUT` |
| `observability.metrics.riverMetricsEnabled` | `OBSERVABILITY_RIVER_METRICS_ENABLED` |
| `observability.metrics.riverMetricsTimeout` | `OBSERVABILITY_RIVER_METRICS_TIMEOUT` |
| `observability.tracing.enabled` | `OBSERVABILITY_TRACING_ENABLED` |
| `observability.tracing.serviceName` | `OBSERVABILITY_TRACING_SERVICE_NAME` |
| `observability.tracing.exporter` | `OBSERVABILITY_TRACING_EXPORTER` |
| `observability.tracing.sampleRatio` | `OBSERVABILITY_TRACING_SAMPLE_RATIO` |
| `observability.tracing.shutdownTimeout` | `OBSERVABILITY_TRACING_SHUTDOWN_TIMEOUT` |

Metrics are enabled by default at `/metrics`. HTTP tracing is disabled by
default and must be paired with normal OpenTelemetry exporter environment
variables through `server.extraEnv`, for example
`OTEL_EXPORTER_OTLP_ENDPOINT` or `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`.

## Prometheus Operator Resources

Prometheus Operator resources are opt-in:

```yaml
observability:
  serviceMonitor:
    enabled: true
  prometheusRule:
    enabled: true
```

When enabled, the chart renders:

- `ServiceMonitor`: selects the Shepherd server service, scrapes the named
  `http` port, uses `observability.metrics.path`, and defaults `jobLabel` to
  `app.kubernetes.io/name` so the packaged `up{job="shepherd"}` alert matches
  Operator-managed scrapes
- `PrometheusRule`: packages the accepted Shepherd recording and alert rules

The chart does not install Prometheus Operator CRDs, Prometheus, Alertmanager,
Grafana, receiver routing, or long-term storage. Those remain cluster-owned.
If `nameOverride` or `observability.serviceMonitor.jobLabel` changes the
resulting Prometheus `job` label, set `observability.prometheusRule.targetJob`
to the same value.

## Validation

`make check-observability` renders the default chart and the monitoring-enabled
chart. The gate verifies:

- default renders include `OBSERVABILITY_*` runtime config
- default renders do not include `ServiceMonitor` or `PrometheusRule`
- monitoring renders include one `ServiceMonitor` and one `PrometheusRule`
- `ServiceMonitor` scrapes `/metrics` on the named `http` port and renders the
  expected job label
- `PrometheusRule` contains the accepted recording and alert rule counts
- Prometheus label templates such as `{{ $labels.queue }}` survive Helm
  rendering

`make validate` includes this gate.
