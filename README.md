# Quorum — a focus group in a box

**Describe a concept. Pick a street. Get a GO / NO-GO verdict from a panel of that neighborhood — every opinion citing its measured Qloo receipt.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Live demo:** https://quorum-akshay.vercel.app

Qloo Agentic Hackathon entry — *"Agents, but with taste"* (deadline Oct 30, 2026).

---

## The problem

The most expensive guess in hospitality and retail is *right concept, wrong street*. A lease runs three years; a real focus group costs $10–40k and weeks; and asking a plain LLM produces culturally blind boilerplate. Quorum runs the focus group in about fifteen seconds, grounded in real measured taste data.

## How it works

1. **Concept (free text).** Describe any idea — "a natural wine bar with vinyl listening nights", "a boba shop for late-night chess players".
2. **Street (anywhere Qloo knows).** "Rainey Street, Austin", "Shimokitazawa, Tokyo", with live autocomplete.
3. **Measured intersection.** The agent resolves your concept into Qloo search signals, adds the street's place entity, and scans the intersection across 9 Qloo domains (brand, place, artist, movie, tv_show, podcast, book, destination, person) over the 250M-entity taste graph — rate-limit-aware, with spaced calls and 429 retries.
4. **A grounded panel reacts.** Four locals speak strictly through their measured receipts — enthusiasts, one designed skeptic, and a rejector whenever the receipt spread warrants an honest no. Every sentence carries its entity, domain, and affinity score.
5. **A verdict with receipts.** GO or NO-GO, the street-lift finding, the unserved-demand gap, and the real people to interview next.

### The fit metric is street lift

Qloo's top returned affinities are ceiling-capped — almost any intersection scores ~0.9 — so raw strength can't tell a good corner from a bad one. Quorum asks the discriminating question instead:

```
intersection scan = affinities(concept signals + street)   → mean A
concept-only scan = affinities(concept signals alone)      → mean B
street lift       = A − B
```

GO requires the full differential to have run, a healthy fit, and a grounded enthusiastic panel. Everything else is NO-GO — including evidence too thin to measure. **Quorum does not bless a pairing it couldn't measure.**

### Honesty fields, by design

Every report states how it was produced:

| Field | Meaning |
|---|---|
| `llmMode` | `live` (LLM-written dialogue, receipt-checked) or `fallback` (deterministic receipt-cited templates) |
| `fitRegime` | `lift` (both differential scans measured) or `strength` (thin scan — verdict reads measured strength) |
| `groundingRate` | share of panel statements citing ≥1 receipt |

## Why it only works with Qloo

The panelists' opinions are *derived from* measured cross-domain affinities. Remove Qloo and there are no receipts, no fingerprints, no street lift — just an LLM making things up. Qloo supplies the measured taste data; the LLM layer (optional) supplies narrative phrasing; the grounding check keeps either voice honest.

## Quickstart

```bash
npm install
cp .env.example .env.local   # add your QLOO_API_KEY (hackathon keys: hackathon.api.qloo.com)
npm run dev                  # http://localhost:3000
npm test                     # 14 offline engine tests (mock Qloo fixtures, no key needed)
```

## API

### `POST /api/quorum/decision`

```json
{ "concept": "a natural wine bar with vinyl listening nights",
  "neighborhood": "Rainey Street, Austin" }
```

Response: the full report — `verdict` (GO/NO-GO), `fitScore`, `fitRegime`, `llmMode`, `groundingRate`, `reasons[]` (street lift + resonance, with receipts), `panel[]`, `gap`, `nextInterviews`. Add `"debug": true` to the body to receive a `diagnostics` block (per-Qloo-call trace: endpoint, status, entity count, latency, retries — no secrets included). Rate-limited 6 req/min per IP; concept 12–400 chars.

### Also

- `GET /api/quorum/places?q=…` — street autocomplete (Qloo `/v2/search`)
- `POST /api/quorum/stream` — SSE variant with a live agent trace
- `POST /api/quorum/compare` — grounded vs ungrounded panel, side by side

## Architecture

```
app/page.tsx                     3-step founder flow: concept → street → verdict dashboard
app/api/quorum/decision/route.ts the verdict endpoint (validation, rate limit, debug traces)
lib/qloo.ts                      Qloo client: 9-domain scan, 320ms call spacing, 429 retries, per-call tracing
lib/agent.ts                     plan → domain-balanced fingerprint (+street lift) → designed panel
lib/decision.ts                  fit calibration, two-rung verdict ladder, gap + pivot suggestion
lib/llm.ts                       OpenAI-compatible client with explicit kind: 'live' | 'fallback'
lib/types.ts                     Receipt · SegmentFingerprint · Claim · PanelStatement · DecisionReport
tests/engine.test.ts             14 offline tests
```

Design decisions worth reading: receipts are selected domain-round-robin so no single domain's popular entities can dominate the panel; the verdict ladder is deliberately two-rung (a PIVOT rung was removed after a 26-run live audit proved it could never fire honestly — Qloo's top-N affinities are structurally positive-biased); and every capability check uses explicit flags, never class-name sniffing. The full engineering story — including the 429 rate-limit investigation, instrumented first — is in [README-SESSION.md](README-SESSION.md).

## Security posture

- **No secrets in code or client bundle.** `QLOO_API_KEY` lives only in host environment variables; no `NEXT_PUBLIC_`/`VITE_` exposure; the shipped JS bundle contains zero credentials (verified by scan).
- **No PII.** No accounts, no database, no storage — inputs are the visitor's own free text, passed as Qloo search queries.
- **Hardened runtime.** Next.js 15.5.28 (clears 22 advisories incl. 2 critical RCEs), minimal production dependencies, input validation and length caps on every endpoint, safe error messages that never leak internals, per-IP rate limiting.
- **Honest failure.** Missing key → clear configuration error, never a fallback pretending to be live.

## Submission links

- **Live demo:** https://quorum-akshay.vercel.app
- **Repo:** https://github.com/AkshayJohn03/QuorumApp
- **Qloo Agentic Hackathon** — "Agents, but with taste", deadline Oct 30 2026
- **Promo:** [`brag-output/brag.mp4`](brag-output/brag.mp4) (22s) · [poster](brag-output/brag.jpg)

## License

MIT — see [LICENSE](LICENSE).

© 2026 Akshay John Xavier
