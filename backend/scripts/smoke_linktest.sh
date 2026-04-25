#!/usr/bin/env bash
# Smoke test against linktest (Railway staging) — runs after each split commit
# is deployed. Asserts each domain probe returns an expected status at BOTH
# /api and /api/users prefixes.
#
# Usage:
#   bash backend/scripts/smoke_linktest.sh
#
# Override base URL:
#   BASE=https://api.link2ur.com bash backend/scripts/smoke_linktest.sh
set -u
BASE="${BASE:-https://linktest.up.railway.app}"

# (method, path, expected_codes_pipe_separated)
PROBES=(
  "POST /csp-report 204|400|422"
  "GET /tasks/1/history 401|403"
  "GET /tasks/1/refund-status 401|403"
  "GET /profile/me 401|403"
  "GET /messages/unread/count 401|403"
  "POST /stripe/webhook 400|422"
  "GET /customer-service/status 200|401|403"
  "GET /translate/metrics 200|401|403"
  "GET /banners 200"
  "GET /faq 200"
  "POST /upload/image 401|403|422"
)

PREFIXES=("/api" "/api/users")
fail=0
for probe in "${PROBES[@]}"; do
  read -r method path expected <<< "$probe"
  for prefix in "${PREFIXES[@]}"; do
    url="${BASE}${prefix}${path}"
    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url")
    if [[ "|$expected|" != *"|$code|"* ]]; then
      echo "✗ $method $url → $code (expected $expected)"
      fail=1
    else
      echo "✓ $method $url → $code"
    fi
  done
done

if [[ $fail -ne 0 ]]; then
  echo ""
  echo "Linktest smoke FAILED. If a commit was just pushed, revert it:"
  echo "  git revert HEAD && git push origin main"
  exit 1
fi
echo ""
echo "Linktest smoke OK ($((${#PROBES[@]} * 2)) probes)."
