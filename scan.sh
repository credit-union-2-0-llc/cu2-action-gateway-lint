#!/usr/bin/env bash
# CU2 Gateway Bypass Lint
# Fails if any scanned file references ANTHROPIC_API_KEY or OPENAI_API_KEY
# without a co-located ANTHROPIC_BASE_URL pointing at the LiteLLM gateway.
set -uo pipefail

GATEWAY_HOSTNAME_PATTERN="${GATEWAY_HOSTNAME_PATTERN:-litellm,gateway}"
EXEMPT_FILE_PATH="${EXEMPT_FILE_PATH:-.gateway-exempt}"
RUNBOOK_URL="https://github.com/credit-union-2-0-llc/ops-platform/wiki/litellm-gateway-runbook"

# Build a grep -E alternation: "litellm,gateway" -> "litellm|gateway"
PATTERN_ALT="$(echo "$GATEWAY_HOSTNAME_PATTERN" | sed 's/,/|/g')"

# ------- File discovery -------
# Bicep anywhere; YAML under k8s/ manifests/ deploy/; .env.example anywhere; docker-compose*.yml
mapfile -t FILES < <(
  {
    find . -type f -name '*.bicep' 2>/dev/null
    find . -type f \( -name '*.yaml' -o -name '*.yml' \) \
      \( -path '*/k8s/*' -o -path '*/manifests/*' -o -path '*/deploy/*' \) 2>/dev/null
    find . -type f -name '.env.example' 2>/dev/null
    find . -type f -name 'docker-compose*.yml' 2>/dev/null
    find . -type f -name 'docker-compose*.yaml' 2>/dev/null
  } | grep -v '/\.git/' | sort -u
)

OFFENDERS=()

for f in "${FILES[@]}"; do
  # find lines referencing the key vars (definition lines, not random comments)
  hits="$(grep -nE '(ANTHROPIC_API_KEY|OPENAI_API_KEY)' "$f" 2>/dev/null || true)"
  [ -z "$hits" ] && continue

  # Look for a gateway base URL in the same file OR sibling bicep/manifest in same dir
  dir="$(dirname "$f")"
  base_url_hit=""

  # Same file
  if grep -E 'ANTHROPIC_BASE_URL' "$f" 2>/dev/null | grep -qE "$PATTERN_ALT"; then
    base_url_hit="self"
  else
    # Sibling files in same dir
    while IFS= read -r sib; do
      [ -z "$sib" ] && continue
      if grep -E 'ANTHROPIC_BASE_URL' "$sib" 2>/dev/null | grep -qE "$PATTERN_ALT"; then
        base_url_hit="$sib"
        break
      fi
    done < <(find "$dir" -maxdepth 1 -type f \( -name '*.bicep' -o -name '*.yaml' -o -name '*.yml' -o -name '.env.example' \) 2>/dev/null)
  fi

  if [ -z "$base_url_hit" ]; then
    while IFS= read -r line; do
      OFFENDERS+=("$f:$line")
    done <<< "$hits"
  fi
done

if [ "${#OFFENDERS[@]}" -eq 0 ]; then
  echo "PASS: no gateway bypass detected."
  exit 0
fi

# ------- Failure path: check exemption -------
echo ""
echo "=========================================="
echo "  CU2 Gateway Bypass Lint — FAIL"
echo "=========================================="
echo ""
echo "Found ${#OFFENDERS[@]} reference(s) to ANTHROPIC_API_KEY / OPENAI_API_KEY"
echo "without a co-located ANTHROPIC_BASE_URL pointing at the LiteLLM gateway"
echo "(pattern: ${GATEWAY_HOSTNAME_PATTERN})."
echo ""
echo "Offenders:"
for o in "${OFFENDERS[@]}"; do
  echo "  - $o"
done
echo ""
echo "Runbook: $RUNBOOK_URL"
echo ""

if [ -f "$EXEMPT_FILE_PATH" ]; then
  non_empty="$(grep -cE '\S' "$EXEMPT_FILE_PATH" || true)"
  has_mention="$(grep -cE '@[A-Za-z0-9_-]+' "$EXEMPT_FILE_PATH" || true)"
  if [ "$non_empty" -ge 3 ] && [ "$has_mention" -ge 1 ]; then
    echo "WARNING: exemption granted via $EXEMPT_FILE_PATH"
    echo "         (>=3 non-empty lines and >=1 @mention found)."
    echo "         This bypass is tolerated but should be reviewed at the next gate."
    exit 0
  else
    echo "Exemption file $EXEMPT_FILE_PATH present but INVALID."
    echo "  required: >=3 non-empty lines AND >=1 @username mention"
    echo "  found: non_empty=$non_empty mentions=$has_mention"
  fi
fi

echo ""
echo "To exempt (discouraged): create $EXEMPT_FILE_PATH with at least"
echo "3 non-empty lines explaining why, and tag at least one reviewer (@user)."
exit 1
