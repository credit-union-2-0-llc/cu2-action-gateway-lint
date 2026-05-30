# cu2-action-gateway-lint

Composite GitHub Action that fails CI when a repo references `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY`) without a co-located `ANTHROPIC_BASE_URL` pointing at the CU2 LiteLLM gateway. Prevents apps from quietly bypassing the gateway and skipping Presidio anonymization, audit logging, and per-tenant cost attribution.

## What it scans

- `*.bicep` (anywhere)
- `*.yaml` / `*.yml` under `k8s/`, `manifests/`, `deploy/`
- `.env.example` (anywhere)
- `docker-compose*.yml` / `docker-compose*.yaml`

A file passes if the same file (or a sibling Bicep / manifest in the same directory) defines `ANTHROPIC_BASE_URL` containing one of the gateway hostname substrings (`litellm` or `gateway` by default).

## Install

Add a single workflow file to your repo:

```yaml
# .github/workflows/gateway-lint.yml
name: Gateway Bypass Lint
on: [pull_request, push]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: credit-union-2-0-llc/cu2-action-gateway-lint@v1
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `gateway-hostname-pattern` | `litellm,gateway` | Comma-separated substrings; at least one must appear in the `ANTHROPIC_BASE_URL` value for it to count as a gateway URL. |
| `exempt-file-path` | `.gateway-exempt` | Path to the optional exemption file at repo root. |

## Exempting (discouraged)

If a legitimate reason exists to ship direct-provider keys (e.g. an isolated red-team sandbox), create `.gateway-exempt` at repo root with:

- at least **3 non-empty lines** explaining why,
- at least **one `@username` mention** of an approver.

Example:

```
Direct Anthropic key required: this repo runs the gateway integration test suite
and must be able to talk to api.anthropic.com without going through itself.
Approved 2026-05 by @kdrake and @hugh-smallwood for the duration of the bring-up.
```

The lint will then emit a `WARNING` instead of failing. Exemptions should be reviewed at the next governance gate.

## Runbook

See: https://github.com/credit-union-2-0-llc/ops-platform/wiki/litellm-gateway-runbook
