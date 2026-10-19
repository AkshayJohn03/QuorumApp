#!/bin/bash
# Verdict diversity audit for https://quorum-akshay.vercel.app/api/quorum/decision
OUT=/d/aria/Projects/Quorum/audit
URL=https://quorum-akshay.vercel.app/api/quorum/decision
mkdir -p "$OUT"
LOG="$OUT/run.log"
echo "=== batch start $(date +%T) ===" >> "$LOG"

run_pair() {
  local idx="$1" concept="$2" street="$3"
  local f="$OUT/r${idx}.json"
  local code=""
  for attempt in 1 2 3 4; do
    code=$(curl -sS --max-time 180 -X POST "$URL" \
      -H "Content-Type: application/json" \
      -d "{\"concept\":\"${concept}\",\"neighborhood\":\"${street}\"}" \
      -o "$f" -w '%{http_code}' 2>>"$LOG")
    local t=$(date +%T)
    echo "pair ${idx} attempt ${attempt} -> HTTP ${code} at ${t}" >> "$LOG"
    if [ "$code" = "429" ]; then
      sleep 20
    elif [ "$code" = "000" ] || [ "$code" -ge 500 ] 2>/dev/null; then
      sleep 15
    else
      break
    fi
  done
  # keep a copy of any non-200 body for inspection, then sleep for rate limit
  if [ "$code" != "200" ]; then
    cp "$f" "$OUT/r${idx}.http${code}.body" 2>/dev/null
  fi
  sleep 12
}

run_pair "02" "natural wine bar with vinyl listening nights" "Rainey Street, Austin"
run_pair "03" "third-wave coffee + vinyl listening bar" "Shibuya, Tokyo"
run_pair "04" "vegan bakery study space" "Kreuzberg, Berlin"
run_pair "05" "hardcore techno gym with cold plunge" "Beverly Hills, Los Angeles"
run_pair "06" "cat cafe by day and natural wine bar by night" "East Austin"
run_pair "07" "rooftop no-phones wine bar" "Williamsburg, Brooklyn"
run_pair "08" "boba shop for late-night chess players" "Taipei"
run_pair "09" "comedy club with a sake list" "Shinjuku, Tokyo"
run_pair "10" "craft brewery with board games" "Manchester, UK"

echo "=== batch done $(date +%T) ===" >> "$LOG"
echo DONE
