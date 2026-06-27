#!/usr/bin/env bash
# test-url.sh: Test cloud.arguswatcher.net to return providers.

set -euo pipefail

URL="${URL:-https://cloud.arguswatcher.net/api/}"
DURATION="${1:-${DURATION:-120}}"
SLEEP="${2:-${SLEEP:-1}}"

end=$(( $(date +%s) + DURATION ))
declare -A count

printf 'GET %s  (duration=%ss, sleep=%ss)\n\n' "$URL" "$DURATION" "$SLEEP"

while [ "$(date +%s)" -lt "$end" ]; do
    response=$(curl -s --max-time 5 -w '\n%{http_code}' "$URL" || true)
    http_code=$(printf '%s' "$response" | tail -n1)
    body=$(printf '%s' "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        cloud="http_$http_code"
    else
        cloud=$(printf '%s' "$body" | jq -r '.cloud_provider // "error"' 2>/dev/null || echo "parse_error")
    fi

    count[$cloud]=$(( ${count[$cloud]:-0} + 1 ))

    printf '%s  %-12s   (aws=%d azure=%d error=%d)\n' \
    "$(date +%H:%M:%S)" "$cloud" \
    "${count[aws]:-0}" "${count[azure]:-0}" "${count[error]:-0}"

    sleep "$SLEEP"
done

echo
echo "Final tally:"

# display total count
for c in "${!count[@]}"; do
    printf '  %-6s %d\n' "$c" "${count[$c]}"
done
