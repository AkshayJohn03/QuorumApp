const fs = require('fs');
const path = require('path');
const dir = 'D:/aria/Projects/Quorum/audit';
const files = fs.readdirSync(dir).filter(f => /^r\d+\.json$/.test(f)).sort();
const tally = {};
const seq = [];
let anomalies = [];
for (const f of files) {
  const raw = fs.readFileSync(path.join(dir, f), 'utf8');
  let d;
  try { d = JSON.parse(raw); } catch (e) {
    console.log(`${f}: PARSE ERROR: ${raw.slice(0, 200)}`);
    continue;
  }
  const v = d.verdict;
  tally[v] = (tally[v] || 0) + 1;
  seq.push(v);
  const fit = d.fitScore;
  const g = d.groundingRate;
  const lift = (d.reasons && d.reasons[0] && d.reasons[0].text) || '(none)';
  const panel = d.panel || [];
  const ungrounded = panel.filter(s => s.grounded === false);
  const degenerate = panel.filter(s => JSON.stringify(s.groundedIn || []).includes('no cultural signals found'));
  const liftDegenerate = /not measurable|too thin/i.test(lift);
  const concept = d.idea || d.concept || '';
  const hood = d.neighborhood || '';
  console.log(`--- ${f} | ${concept} @ ${hood}`);
  console.log(`verdict=${v} fit=${fit} grounding=${g} panel=${panel.length} ungrounded=${ungrounded.length} gap=${d.gap ? 'yes' : 'null'} pivot=${d.pivot ? 'yes' : 'no'}`);
  console.log(`lift: ${lift}`);
  if (ungrounded.length) {
    anomalies.push(`${f}: ${ungrounded.length} ungrounded panel statement(s)`);
    for (const u of ungrounded) console.log(`  UNGROUNDED [${u.stance}]: ${String(u.text).slice(0, 140)}`);
  }
  if (degenerate.length) console.log(`  DEGENERATE receipts on ${degenerate.length}/${panel.length} panel statements ("no cultural signals found")`);
  if (liftDegenerate) console.log(`  LIFT-FALLBACK: reasons[0] says street lift not measurable`);
  if (fit === 0.5) console.log(`  CONSTANT-FIT WARNING: fitScore exactly 0.5`);
  // also record which entities receipts used
  const ents = new Set();
  for (const r of (d.reasons || [])) for (const rc of (r.receipts || [])) ents.add(`${rc.entity} [${rc.domain}] a=${rc.affinity}`);
  console.log(`receipts: ${[...ents].slice(0, 6).join(' | ')}`);
}
console.log('\n=== TALLY ===');
console.log(JSON.stringify(tally));
console.log('sequence: ' + seq.join(' -> '));
console.log('\n=== ANOMALIES ===');
console.log(anomalies.length ? anomalies.join('\n') : 'none beyond per-row notes');
