#!/bin/bash
OUT=/d/aria/Projects/Quorum/audit
URL=https://quorum-akshay.vercel.app/api/quorum/decision
LOG="$OUT/run.log"
echo "=== batch2 start $(date +%T) ===" >> "$LOG"

run_pair() {
  local idx="$1" concept="$2" street="$3"
  local f="$OUT/r${idx}.json"
  local code=""
  for attempt in 1 2 3 4; do
    code=$(curl -sS --max-time 180 -X POST "$URL" \
      -H "Content-Type: application/json" \
      -d "{\"concept\":\"${concept}\",\"neighborhood\":\"${street}\"}" \
      -o "$f" -w '%{http_code}' 2>>"$LOG")
    echo "pair ${idx} attempt ${attempt} -> HTTP ${code} at $(date +%T)" >> "$LOG"
    if [ "$code" = "429" ]; then sleep 20
    elif [ "$code" = "000" ] || [ "$code" -ge 500 ] 2>/dev/null; then sleep 15
    else break; fi
  done
  sleep 12
}

# PIVOT/GO probes on well-known food/culture streets
run_pair "11" "natural wine bar with a natural wine list" "Le Marais, Paris"
run_pair "12" "record bar with hi-fi listening sessions" "Shinjuku, Tokyo"
run_pair "13" "sunset rooftop wine bar with small plates" "Silver Lake, Los Angeles"
run_pair "14" "izakaya with a natural wine list" "Nakameguro, Tokyo"
run_pair "15" "artisan gelato counter" "Bologna, Italy"
# determinism/cache probe: exact repeat of pair 05
run_pair "16" "hardcore techno gym with cold plunge" "Beverly Hills, Los Angeles"

echo "=== batch2 done $(date +%T) ===" >> "$LOG"
echo DONE
