---
name: gcx-metrics-logs
description: >
  Query metrics (via Prometheus/Thanos) and logs (via Loki v2) using the gcx CLI in agent mode.
  Designed for quick observability lookups—finding logs for services, checking metric trends,
  and exploring labels/streams without opening a browser. Read-only; never modifies state.
license: MIT
compatibility: opencode
metadata:
  audience: developers, sre
  workflow: observability
---

# Skill: gcx-metrics-logs

Query metrics and logs from the terminal using `gcx`, the Grafana Cloud CLI.

**Arguments:** `$ARGUMENTS` (e.g., a LogQL / PromQL expression, service name, grep term,
or a natural-language request like "show me 5xx errors for nginx in the last hour")

> **⚠️ CRITICAL: Always use `--agent` flag**
>
> This skill is consumed by an AI agent (Sisyphus / OpenCode). Every `gcx` command
> MUST include the `--agent` flag to ensure JSON-only output, no interactive spinners,
> no color codes, and no terminal UI prompts. Without `--agent`, output may be corrupted
> by ANSI escape sequences or TUI elements, making it impossible for the agent to parse.
>
> **Default behaviour**: All examples below include `--agent`. When formulating any new
> command, append `--agent` immediately after `gcx` and before the subcommand, e.g.:
> ```bash
> gcx --agent metrics query 'up' --since 5m
> ```

## Overview

This skill uses the `gcx` CLI (installed at `/usr/local/bin/gcx`) to query:

- **Metrics** via the **Metrics Platform** (Thanos / Prometheus) — the default Prometheus datasource
- **Logs** via **Loki v2** — the primary log aggregation backend

`gcx` is pre-configured on this machine with a default context connecting to
`https://monitor.evroc.dev`.

## Data Sources

| Signal      | Backend             | Datasource UID         | Default? | Description                                                                                                                     |
|-------------|---------------------|------------------------|----------|---------------------------------------------------------------------------------------------------------------------------------|
| **Metrics** | Prometheus / Thanos | `prometheus` (default) | Yes      | Aggregated metrics from all clusters via Thanos Query Frontend (`thanos-observer-query-frontend.thanos.svc.cluster.local:9090`) |
| **Logs**    | Loki v2             | `loki-v2`              | Yes      | Centralised log store (`loki-v2-gateway.loki-v2.svc.cluster.local`)                                                             |
| Logs        | Loki (v1)           | `loki`                 | No       | Legacy Loki instance (`loki-gateway.loki.svc.cluster.local`)                                                                    |
| Metrics     | Billing/Usage       | `billing-db`           | No       | PostgreSQL billing records (`billing-records-r.metrics-processing-system.svc.cluster.local:5432`)                               |
| Logs        | Audit Logs          | `audit-logs-db`        | No       | ClickHouse audit log store (`clickhouse-auditlogsdb.audit-logs-db.svc.cluster.local:8123`)                                      |

You typically do **not** need to pass `--datasource` explicitly because `gcx` uses the
correct default for the signal you query (`metrics` vs `logs`).

## Authentication

`gcx` is already authenticated via a service-account token stored in
`~/.config/gcx/config.yaml`. No login is required.

If you ever need to verify:

```bash
gcx config check          # verify token is valid
gcx config view            # show current context
gcx config list-contexts   # show all contexts
```

## Key Commands

### 1. Query Metrics (PromQL)

```bash
# Basic instant query
gcx --agent metrics query 'up'

# Range query — last 1 hour with 15s step
gcx --agent metrics query 'rate(http_requests_total[5m])' --since 1h --step 15s

# Visualise as an in-terminal graph
gcx --agent metrics query 'sum(rate(node_cpu_seconds_total[5m])) by (mode)' --since 1h -o graph

# JSON output for piping to jq
gcx --agent metrics query 'up{job="node-exporter"}' --since 30m -o json

# Query a specific datasource explicitly
gcx --agent metrics query -d prometheus 'up' --since 5m
```

### 2. Query Logs (LogQL)

```bash
# All logs for a service in the last 30 minutes
gcx --agent logs query '{app="nginx"}' --since 30m

# Logs matching a text substring (case-sensitive, ~grep-like)
gcx --agent logs query '{app="api"} |= "error"' --since 1h

# Exclude noisy health-check lines
gcx --agent logs query '{app="api"} != "/healthz"' --since 1h

# Regex match
gcx --agent logs query '{app="api"} |~ "(error|panic|fatal)"' --since 1h

# JSON log field extraction and filter
gcx --agent logs query '{app="api"} | json | level="error"' --since 1h

# Limit number of lines (default 50, max 5000)
gcx --agent logs query '{app="ingress"} |= "500"' --since 15m --limit 200

# Live tail (if supported by datasource)
gcx --agent logs query '{app="myapp"}' --since 1m --follow
```

### 3. Discover Labels & Streams

```bash
# List all metric labels
gcx --agent metrics labels

# Values of a specific label
gcx --agent metrics labels -l job

# List all log stream labels
gcx --agent logs labels

# Values of a log label
gcx --agent logs labels -l app

# Find active log streams for a selector
gcx --agent logs series --match '{app="nginx"}'
```

### 4. Explore Datasources

```bash
# List all configured datasources
gcx --agent datasources list

# Get details of a datasource
gcx --agent datasources get loki-v2
```

### 5. Use the Knowledge Graph (kg)

Grafana Knowledge Graph (kg) knows about our telemetry topology:

```bash
# List schema / scopes / known telemetry configs
gcx --agent kg describe
```

## Common Query Patterns for Our Infrastructure

### Node / Host Metrics

```bash
# CPU utilisation by mode
gcx --agent metrics query 'sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) by (instance, mode)' --since 1h

# Memory utilisation %
gcx --agent metrics query '(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100' --since 1h

# Disk space warning (< 10 % free)
gcx --agent metrics query 'node_filesystem_avail_bytes / node_filesystem_size_bytes * 100 < 10' --since 5m

# High load
gcx --agent metrics query 'node_load1 > 4' --since 10m
```

### Kubernetes / Container Metrics

```bash
# Pod restart rate
gcx --agent metrics query 'sum(rate(kube_pod_container_status_restarts_total[10m])) by (namespace, pod)' --since 1h

# Container CPU throttling
gcx --agent metrics query 'rate(container_cpu_cfs_throttled_seconds_total[5m])' --since 30m

# High memory usage containers
gcx --agent metrics query 'container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.85' --since 10m
```

### API / HTTP Error Patterns

```bash
# 5xx rate per handler
gcx --agent metrics query 'sum(rate(http_requests_total{status=~"5.."}[5m])) by (handler)' --since 1h

# 95th percentile latency
gcx --agent metrics query 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler))' --since 1h

# Error logs for an API service
gcx --agent logs query '{app="api-gateway"} |= "error"' --since 30m

# Combined: logs for a specific trace ID
gcx --agent logs query '{app="api-gateway"} |= "trace_id=abc123"' --since 1h
```

### Storage / Ceph Patterns

```bash
# Ceph health
gcx --agent metrics query 'ceph_health_status' --since 5m

# High bucket usage bytes (from metrics proxy whitelist)
gcx --agent metrics query 'max_bucket_usage_bytes' --since 1h
```

## Output Formats

| Flag       | Output                                                   |
|------------|----------------------------------------------------------|
| (none)     | Human-readable table (default)                           |
| `-o json`  | JSON arrays/objects (good for piping to `jq`)            |
| `-o yaml`  | YAML (human-readable structured)                         |
| `-o graph` | In-terminal Unicode sparkline / bar chart (metrics only) |

## Flags Reference

| Flag                            | Applies To            | Description                                             |
|---------------------------------|-----------------------|---------------------------------------------------------|
| `--since DURATION`              | metrics, logs, traces | Relative time window, e.g. `5m`, `1h`, `24h`            |
| `--from TIMESTAMP`              | metrics, logs, traces | Explicit RFC3339 start time                             |
| `--to TIMESTAMP`                | metrics, logs, traces | Explicit RFC3339 end time                               |
| `--step DURATION`               | metrics               | Query resolution, e.g. `15s`, `1m`                      |
| `--limit N`                     | logs                  | Max log lines to return (default 50, absolute max 5000) |
| `-d UID` / `--datasource UID`   | all                   | Override datasource (usually unnecessary)               |
| `-o FORMAT` / `--output FORMAT` | all                   | `table`, `json`, `yaml`, `graph`                        |
| `--verbose`                     | all                   | Increase verbosity (repeat up to 3×)                    |
| `--agent`                       | all                   | JSON-only output, no spinners (useful for agents)       |

## Time Ranges

- `--since 5m`  → last 5 minutes (quick health check)
- `--since 15m` → last 15 minutes (recent incidents)
- `--since 1h`  → last hour (standard investigation window)
- `--since 24h` → last 24 hours (daily trends)
- `--since 7d`  → last 7 days (weekly patterns)

You can also use absolute times:

```bash
gcx metrics query 'up' --from 2026-06-01T08:00:00Z --to 2026-06-01T09:00:00Z
```

## Troubleshooting

| Symptom                             | Fix                                                                                                            |
|-------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `401 Unauthorized`                  | `gcx config check` — token may be expired; re-run `gcx login` or update `~/.config/gcx/config.yaml`            |
| `connection refused` / timeout      | Verify `gcx config view` shows `server: https://monitor.evroc.dev`                                             |
| Empty results but query looks right | Check label names with `gcx logs labels` or `gcx metrics labels` — label names may differ from what you expect |
| `no datasource found`               | Pass `-d loki-v2` or `-d prometheus` explicitly                                                                |
| Labels/values return nothing        | Try `gcx logs series --match '{app="<name>"}'` to discover active streams                                      |
| Query syntax error                  | Verify PromQL / LogQL syntax; `gcx` passes the expression directly to the backend                              |
| Too much output                     | Add `--limit 20` (logs) or narrow `--since` window                                                             |

## LogQL Quick Reference

Before

| Pattern                                        | Meaning                                                    |
|------------------------------------------------|------------------------------------------------------------|
| `{app="nginx"}`                                | Stream selector — all logs from `app=nginx`                |
| `\|= "error"`                                  | Line contains substring "error"                            |
| `!= "debug"`                                   | Line does NOT contain "debug"                              |
| `\|~ "err.*"`                                  | Line matches regex                                         |
| `!~ "healthz"`                                 | Line does NOT match regex                                  |
| `\| json`                                      | Parse line as JSON; extracts fields                        |
| `\| json field="value"`                        | JSON filter after parsing                                  |
| `\| logfmt`                                    | Parse line as logfmt (key=value)                           |
| `{app="x"} \|= "err" \| json \| level="error"` | Combined: stream select → grep → JSON parse → field filter |


## PromQL Quick Reference

| Pattern                         | Meaning                                  |
|---------------------------------|------------------------------------------|
| `up`                            | Instant vector — 1 if target is up       |
| `up{job="node-exporter"}`       | Filtered instant vector                  |
| `rate(http_requests_total[5m])` | Per-second rate over 5 minutes           |
| `sum(...) by (label)`           | Aggregate and group by label             |
| `histogram_quantile(0.95, ...)` | Calculate 95th percentile from histogram |
| `> 0.85`                        | Scalar filter — only values > 0.85       |
| `\|~ "5.."`                     | Regex label matcher (status codes 5xx)   |

## Notes

- **Read-only**: This skill only runs `gcx query` / `gcx labels` / `gcx series` / `gcx describe`. It
  never runs `gcx create`, `gcx delete`, `gcx edit`, or `gcx resources push`.
- **Agent flag is mandatory**: Because this skill is invoked by an AI agent, **every `gcx` command
  must include the `--agent` flag** immediately after `gcx` (before the subcommand). This suppresses
  interactive TUI elements, spinners, color codes, and ensures clean JSON/machine-readable output.
  Without it, parsing may fail.
- **Datasource defaults**: `gcx` automatically uses the configured default datasource for the signal
  type (`metrics` → Prometheus/Thanos, `logs` → Loki v2). You only need `-d` when querying a
  non-default datasource.
- **Context**: If multiple contexts exist, `gcx` uses `current-context` from
  `~/.config/gcx/config.yaml`. Check with `gcx --agent config view`.
- **Performance**: Very broad queries (e.g. `{app!=""}` over 24h) can be expensive and slow. Always
  scope with specific labels and narrow `--since` windows first.
- **Label discovery**: If you don't know the exact label names, use `gcx --agent logs labels` or
  `gcx --agent metrics labels` first, then refine.
- **Namespaces**: Many Kubernetes metrics include a `namespace` label; use it to scope queries if
  the cluster has many tenants.
