# Quorum — Session README (Full Project Journey)

**Everything that happened in the build of Quorum, compacted from the entire working session.**
This is the history-and-decisions companion to [README.md](README.md) (the product readme).
Live demo: https://quorum-akshay.vercel.app · Public repo: https://github.com/AkshayJohn03/QuorumApp
Private working repo: `AkshayJohn03/quorum-app` (main) · Qloo Agentic Hackathon — "Agents, but with taste" · deadline Oct 30, 2026

---

## 1. What Quorum is

The most expensive guess in hospitality is *right concept, wrong street* — a lease is three years, a real focus group costs $10–40k. Quorum runs one in minutes:

1. **Describe a concept** (free text, any idea) → 2. **pick a street** (anywhere Qloo knows) → 3. the agent **measures the intersection** of the concept's audience and the street across 9 Qloo domains over the 250M-entity taste graph → 4. a **panel of 4 locals reacts through their measured fingerprint**, every sentence citing its Qloo receipt → 5. a **GO / NO-GO verdict** with the unserved-demand gap and the real people to interview next.

**Why it can only exist with Qloo:** panelist opinions are *derived from* measured cross-domain affinities. Remove Qloo and there are no receipts — just an LLM making things up. **Why the LLM is optional:** Qloo supplies the measured data (entities, affinities, fingerprints); the LLM supplies narrative intelligence (planning searches, decomposing claims, writing dialogue). Without an LLM key the panel uses a deterministic receipt-cited template voice; with one, dialogue varies naturally — the grounding check keeps either voice honest. Every report ships `llmMode: 'live' | 'fallback'` and `fitRegime: 'lift' | 'strength'` so a judge can always interpret the numbers.

## 2. Architecture (standalone — no internal frameworks)

```
app/page.tsx                     3-step founder flow: concept → street → verdict dashboard
app/api/quorum/decision/route.ts POST {concept, neighborhood} → verdict report (rate-limited 6/min/IP)
app/api/quorum/stream/route.ts   SSE variant (live agent trace)
app/api/quorum/places/route.ts   debounced street autocomplete against Qloo /v2/search
app/api/quorum/compare/route.ts  grounded vs ungrounded panel side-by-side
lib/qloo.ts                      HttpQloo: 9-domain scan, 320ms call spacing, 429 retry w/ Retry-After, per-call trace
lib/llm.ts                       LLMClient protocol with explicit kind: 'live' | 'fallback'
lib/agent.ts                     plan → fingerprint (+street-lift stats) → designed panel → decision
lib/decision.ts                  fit calibration, verdict ladder, gap + pivot suggestion
lib/types.ts                     Receipt · SegmentFingerprint (stats) · Claim · PanelStatement · DecisionReport
tests/engine.test.ts             14 offline tests (mock Qloo fixtures)
brag-output/                     brag.mp4 (22s promo) · brag.jpg poster · share-copy.txt · composition/
```

## 3. The bug saga — each root cause, fix, and the evidence

### 3.1 Production build was dead
`next build` failed with a misleading SWC error ("Unexpected token `div`" pointing hundreds of lines away). Root cause: a JSX fragment `<>` opened inside `{phase === 'form' && (` was never closed. Also queued: two invalid Tailwind classes in `globals.css` (`bg-accent/8` — 8 isn't a legal opacity step; `text-body` — undefined). Fixed all three; build green since.

### 3.2 The panel literally said "[mock]" — the worst one
The LLM-capability check sniffed `llm.constructor.name !== 'EchoFallback'`. Webpack minifies class names in production bundles, so the mock fallback **impersonated a real LLM** and its `[mock]` placeholder reached the report; grounding showed 0%. Fix: an explicit `kind: 'live' | 'fallback'` flag on the client — minification-proof. Same bug fixed in the stream and compare routes. The offline voice now writes real sentences citing real entities ("You had me at Austin Street Brewery — that is exactly the energy I'm on Rainey Street for.").

### 3.3 The panel design now matches the product's promise
The site says skeptics and one rejector are "convened on purpose" — now they are: seat 2 is always a skeptic, seat 4 is a rejector whenever the receipt spread warrants an honest no (`spread ≥ 0.15` or floor `< 0.6`). Every stance still speaks strictly through its own measured receipt, which is why grounding is 100% rather than theater.

### 3.4 The fit score saga (three iterations, evidence-driven each time)
- **v1 — mean of top receipts:** meaningless; Qloo's top-N affinities are ceiling-capped (~0.9 for any pairing), so everything scored GO 0.9. "Vape shop for cats" would have been GO.
- **v2 — street lift:** measure the concept-audience affinities *with* the street vs *without*; fit from the differential. Better — but produced fit **exactly 0.50** on thin scans (the fallback path forced `conceptOnlyMean = intersectionMean`, pinning lift at exactly 0). Fixed by suppressing `stats` unless **both** scans return real affinity data.
- **v3 (final) — calibrated two-rung ladder:** an 18-run live audit measured lift spanning −1.2 to +2.3 points; fit = `0.65 (street compatible) + liftPts × 0.14 + strength bonus`. A follow-up 8-run probe proved a middle **PIVOT rung can never fire** (0/26 live runs including 6 engineered mismatches — Qloo's top-N intersection affinities are structurally positive-biased). Per review directive ("prove it or drop it"), PIVOT was dropped. Final ladder: **GO** = full differential data + fit ≥ 0.62 + ≥2 grounded enthusiasts + no hard no; **NO-GO** = everything else, including thin evidence ("Quorum does not bless a pairing it couldn't measure") and hard panel rejections. Both rungs proven live (GO across good pairings 0.64–0.86; NO-GO via genuine −0.9pt dilution).

### 3.5 The vanishing verdict page
The entire verdict dashboard rendered *inside* the `phase === 'form'` conditional — the moment the run completed and phase flipped to `'report'`, React unmounted it ("third page opens and right away disappears"). Now gated on `report` itself, independent of the form block.

### 3.6 Street autocomplete
The `/api/quorum/places` route existed but the page never called it ("street search never suggests anything"). Wired: debounced 250ms Qloo search, keyboard navigation, domain labels, the pre-styled dropdown.

### 3.7 The 429 saga — the headline engineering win
Symptom: on Vercel (works locally), 14/16 audit runs returned degenerate 2-receipt fingerprints ("no cultural signals found"), fit pinned at 0.70, NO-GO everywhere, and responses suspiciously fast.

Method (per review directive: **instrument first, no blind fixes**):
- HttpQloo was wired to record one trace per call (endpoint, summary, HTTP status, entity count, ms, error, retry count), surfacing via a debug-gated `diagnostics` block and Vercel runtime logs.
- The trace **confirmed the cause**: each run makes ~32 Qloo calls; the first 5 succeed, then both parallel bursts (10 domains × 17 signals, then the concept-only round) blow through the hackathon key's rate limit within ~2 seconds — **27/32 calls failing with HTTP 429 in 3–30ms**, all swallowed by `Promise.allSettled`.
- It also **corrected the latency inference**: the "1.3–2s is too fast for ~20 calls" suspicion was wrong — calls are serial bursts, and responses were fast because most calls *never happened*.
- It **resolved the determinism question**: Vercel has no LLM key (only `QLOO_API_KEY`/`QLOO_BASE_URL`), so byte-identical repeat responses are the deterministic fallback voice working as designed — not a cache. Now stated in every report via `llmMode`.

The evidence-matched fix: every Qloo call takes a **spaced slot** (320ms minimum gap; parallel callers serialize automatically) and **429s retry twice honoring `Retry-After`** (capped 8s). Waste was cut: word-searches already covered by planned queries are skipped, planned-query results capped at 2, and the concept-only lift round runs only on domains that produced receipts (~21–24 calls/run, ~12s, inside the 60s budget). Post-fix live proof: 18-run audit — 72/72 panelists grounded in real named entities (zero hotels, zero "the street itself"), 392 calls with **zero 429s** (124 transient retries absorbed), `fitRegime: 'lift'` 18/18.

### 3.8 video_game 400 — dropped on evidence
`urn:entity:video_game` as an insights filter.type fails HTTP 400 **deterministically** (18/18 live runs) while all sibling domains succeed with identical signals. Removed from the scan; 9 domains remain.

### 3.9 Known honest limitation (disclosed, not hidden)
Qloo search returns entities for *any* text, so a gibberish concept latches onto adjacent real words ("lounge") and yields a confident GO — the receipts make the measured basis transparent, but garbage in still gets a well-lit answer. Inherent to fuzzy search; covered by the honesty clause.

## 4. Security incidents and resolution

- **The hardcoded key (twice).** During an early deployment emergency (Vercel env var not reaching the serverless function), the hackathon API key was baked into source with the reasoning "repo is private, key is hackathon-scoped." That reasoning was expedient and wrong — it was the root cause of the first independent audit's findings too. Lesson recorded: **secrets belong in the environment, never in source, regardless of repo visibility.** The `.gitignore` always covered `.env*` — the leak vector was source code, not env files.
- **Resolution:** key removed from code (env-only, clear error if missing — commit `bcc7c30`), then a **clean public repo** was published: `AkshayJohn03/QuorumApp` — exported from the tracked tree **without git history**, secret-audited before and after push (`hack_` token, `.env` files, raw-file fetches), confirmed public. Later re-synced as a single fresh commit `a7ad850` containing the final code, re-verified by raw fetch. The name `Quorum` was taken by a private repo on the account, hence `QuorumApp`.
- **Key rotation remains open (the one open item).** The Qloo key form is account-bound — it cannot be submitted on the user's behalf, and no one pretended otherwise. The exposed key is shared and burnable, and the demo now depends on ~22 calls/run succeeding, so rotation is urgent before the demo. Swap procedure when the fresh key arrives: `npx vercel env rm QLOO_API_KEY production` → add new key → `npx vercel --prod --yes` → one `debug:true` call to re-verify per-call statuses/retries against the new key's limits (320ms spacing gives ~5× headroom inside the 60s budget).

## 5. Deployments

- Old project `quorum` (auto-suffixed URL `quorum-kappa-six.vercel.app`) was **deleted** and recreated as `quorum-akshay` so the production URL is clean natively; kappa-six now 404s. Env vars (`QLOO_API_KEY`, `QLOO_BASE_URL`) live in Vercel production only.
- Public URL verified end-to-end: homepage 200, live decision API returning real receipt-cited verdicts, debug diagnostics available via `"debug": true` in the request body.

## 6. Independent verification (the auditor's pass)

An independent reviewer reproduced the claims on their own tests: the same concept that returned NO-GO 0.50 in ~2s with degenerate receipts pre-fix returned **GO 0.78, regime lift, ~12s, real receipts** post-fix. Their verdict: the instrumentation-first method, the honest reversal ("responses were fast because most calls never happened"), and the transparency fields are the trust-builders. Two standing pressures: key rotation urgency (above) and re-verifying rate limits after the key swap (procedure ready).

## 7. The brag video

- `brag-output/brag.mp4` — 22.0s, 1920×1080, h264+aac, 2.2MB, poster baked as frame 0. Built with Hyperframes; `npx hyperframes check` passed clean (0 errors, 58/58 WCAG AA). Scenes: lease-vs-panel hook → concept typed with key ticks → street + convening pulse → four receipt-stamped panel turns ("receipt: Austin Street Brewery · brand · 0.91" verbatim) → GO landing on the track's biggest hit. No PIVOT anywhere (matches the shipped ladder).
- `brag-output/brag.jpg` — the GO-dashboard poster (frame 19.45s, picked not arbitrary).
- `brag-output/share-copy.txt` — "Quorum convenes a focus group of your street — panelists built from measured taste data, every opinion carrying its Qloo receipt — and hands you GO or NO-GO before you sign the lease. Live: quorum-akshay.vercel.app"
- First build agent died silently after audio extraction; a finisher agent reused the plan, brief, music, and `audio-data.json`, and completed composition → check → render → poster → share copy.

## 8. Working principles this project enforced (the meta-lessons)

1. **Instrument first, then fix the confirmed cause — never a blind fix.** The 429 diagnosis (not the plausible place-entity theory) was the real cause.
2. **Latency vibes vs call counts** — fast responses can mean "most calls never happened." Verify with per-call evidence.
3. **Determinism claims need env facts** — check what's actually configured before theorizing.
4. **Prove a rung live or drop it** — a verdict ladder with a dead middle rung is a demo risk; two honest rungs beat three performative ones.
5. **Transparency fields are product, not debug** — `llmMode` and `fitRegime` let anyone interpret the numbers.
6. **A metric that can't discriminate is decoration** — ceiling-capped affinities forced three fit-score iterations until the differential (street lift) carried real signal.
7. **Never re-derive trust from class names** — minification-proof capability flags (`kind`), not `constructor.name` sniffing.
8. **Secrets: env-only, always** — and a clean-history public repo is the submission artifact, audited before *and* after push.

## 9. Glossary

- **Receipt** — a Qloo entity (name, domain, affinity 0–1) cited by a claim or panel statement.
- **Grounding rate** — % of panel statements citing ≥1 receipt; displayed on every report.
- **Street lift** — mean affinity of the concept×street intersection minus the concept-only scan, in affinity points; the discriminating fit signal.
- **fitRegime** — `lift` (both scans measured) or `strength` (thin scan; verdict reads measured strength; Quorum then refuses to bless the pairing).
- **llmMode** — `live` (LLM-generated dialogue, grounding-checked) or `fallback` (deterministic receipt-cited templates).
- **Two-rung ladder** — GO (measured, undiluted fit + grounded enthusiastic panel) / NO-GO (weak, thin, or hard-rejected).
- **Hard no** — a rejector whose own cited receipt measures < 0.55; the data itself rejects.

## 10. Where everything lives

| Artifact | Path / URL |
|---|---|
| Live demo | https://quorum-akshay.vercel.app |
| Public repo (submission) | https://github.com/AkshayJohn03/QuorumApp (single commit `a7ad850`) |
| Private working repo | `AkshayJohn03/quorum-app` (this directory; full history) |
| Product README | [README.md](README.md) |
| This session README | `README-SESSION.md` (Quorum project root) |
| Brag video / poster / copy | `brag-output/brag.mp4` · `brag.jpg` · `share-copy.txt` |
| Audit evidence (external) | `F:\temp\quorum_audit\` (18-run raw JSON + runners, outside the repo) |
| Env config | Vercel project `quorum-akshay`: `QLOO_API_KEY`, `QLOO_BASE_URL` (production); local `.env.local` (gitignored) |

*Compacted from the full working session, October 2026. Contains no secrets by design.*
