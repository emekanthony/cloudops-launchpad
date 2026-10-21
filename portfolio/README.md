# CloudOps Launchpad — Portfolio Screenshots

Every screenshot below was captured from the running lab: a local kind cluster, the live
Prometheus/Grafana stack, and the real GitHub Actions run. Terminal screenshots are the actual
script output, rendered as a terminal window.

## Observability

### 1. Grafana dashboard
Request rate by handler, p50/p95/p99 latency, responses by status class, 5xx error ratio, pod
memory, and restarts. The dashboard is provisioned automatically from the Helm chart
(a ConfigMap picked up by the Grafana sidecar).

![Grafana dashboard](01-grafana-dashboard.png)

### 5. Prometheus scrape targets
The ServiceMonitor in the chart makes Prometheus discover both API pods automatically.

![Prometheus targets](05-prometheus-targets.png)

### 6. Alert rules
A PrometheusRule shipped in the chart: API down, 5xx ratio above 5 %, and restart loops.

![Prometheus alert rules](06-prometheus-alert-rules.png)

## CI/CD and security

### 2. GitHub Actions pipeline
Lint → tests against Postgres → image build → Trivy scan → deploy to an ephemeral kind cluster
→ automated recovery and backup drills. Runs on every push.

![GitHub Actions CI run](02-github-actions-ci-run.png)

### 7. Tests and lint
11 API tests that run against a real PostgreSQL database (not mocks), after Alembic migrations.

![pytest and ruff](07-tests-and-lint.png)

### 8. Trivy security scans
The container image has 0 fixable HIGH/CRITICAL CVEs, and the Dockerfile and every Helm template
pass the misconfiguration checks: non-root, read-only root filesystem, dropped capabilities,
and seccomp. The first scan caught a vulnerable Starlette version; the fix was to upgrade and
pin it.

![Trivy scans](08-trivy-security-scan.png)

## Platform

### 3. API (FastAPI / OpenAPI)
![Swagger UI](03-api-swagger-docs.png)

### 4. Kubernetes resources
Two API replicas, a Postgres StatefulSet with persistent volumes for data and backups, the
nightly backup CronJob, and both Helm releases.

![Kubernetes resources](04-kubernetes-resources.png)

## Operational drills

### 9. Failed deployment → automatic detection → rollback
A release with a non-existent image fails. The old pods keep serving traffic throughout
(`maxUnavailable: 0`). `recover.sh` detects the failed release, shows why the pods are
unhealthy, rolls back to the last good revision, and smoke-tests the result.

![Recovery drill](09-drill-failed-deploy-recovery.png)

### 10. Backup → restore → verify
`pg_dump` plus a manifest of per-table row counts and md5 checksums. The dump is restored into
a scratch database and verified to match exactly.

![Backup and restore verification](10-drill-backup-restore-verify.png)

### 11. Verification catches a bad backup
Negative test: the manifest is altered, and verification fails with exit code 1. The check can
actually fail, so a PASS means something.

![Tamper detection](11-drill-restore-verify-detects-tampering.png)
