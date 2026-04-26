#!/usr/bin/env bash
# Smoke test against linktest (Railway staging) — runs after each split commit
# is deployed. Each probe asserts a status at the prefix(es) that domain is
# actually mounted at (see _SPLIT_ROUTERS in app/main.py).
#
# After the 2026-04-26 prefix audit, four domains are single-mounted at /api:
# translation, upload_inline, refund, payment_inline. The probe for those
# only hits /api/<path>; hitting /api/users/<path> would now correctly 404.
#
# Usage:
#   bash backend/scripts/smoke_linktest.sh
#
# Override base URL:
#   BASE=https://api.link2ur.com bash backend/scripts/smoke_linktest.sh
set -u
BASE="${BASE:-https://linktest.up.railway.app}"

# (method, path, expected_codes_pipe_separated, prefixes_space_separated)
PROBES=(
  "POST /csp-report 204|400|422 /api /api/users"
  "GET /tasks/1/history 401|403 /api /api/users"
  "GET /tasks/1/refund-status 401|403 /api"
  "GET /profile/me 401|403 /api /api/users"
  "GET /messages/unread/count 401|403 /api /api/users"
  "POST /stripe/webhook 400|422 /api"
  "GET /customer-service/status 200|401|403 /api /api/users"
  "GET /translate/metrics 200|401|403 /api"
  "GET /banners 200 /api /api/users"
  "GET /faq 200 /api /api/users"
  "POST /upload/image 401|403|422 /api"
)

fail=0
total=0
for probe in "${PROBES[@]}"; do
  # shellcheck disable=SC2086
  set -- $probe
  method=$1
  path=$2
  expected=$3
  shift 3
  for prefix in "$@"; do
    total=$((total + 1))
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
echo "Linktest smoke OK ($total probes)."
