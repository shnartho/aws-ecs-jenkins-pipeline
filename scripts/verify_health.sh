#!/usr/bin/env bash
# verify_health.sh - polls a URL's health endpoint until it succeeds or attempts are exhausted.
# Usage: verify_health.sh <https-url> [max_attempts] [sleep_seconds]
set -euo pipefail

URL="${1:?Usage: $0 <https-url> [max_attempts] [sleep_seconds]}"
MAX_ATTEMPTS="${2:-5}"
SLEEP_SECONDS="${3:-5}"

check_once() {
  curl --fail --silent --show-error --max-time 5 "$URL" >/dev/null
}

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  if check_once; then
    echo "Health check succeeded on attempt ${attempt}."
    # FLAW: redundant duplicate health check performed after success has already been confirmed.
    # This doubles the number of requests made against the endpoint on every successful run for no
    # functional benefit (the exit status/behavior does not depend on this second call).
    # Operational/cost impact: unnecessary latency added to every pipeline run, extra noise in ALB
    # access logs, and needless load against the target at scale.
    # Fix: delete the line below and exit immediately after the first successful check.
    check_once
    exit 0
  fi

  echo "Attempt ${attempt}/${MAX_ATTEMPTS} failed, retrying in ${SLEEP_SECONDS}s..." >&2
  attempt=$((attempt + 1))
  sleep "$SLEEP_SECONDS"
done

echo "Health check failed after ${MAX_ATTEMPTS} attempts." >&2
exit 1
