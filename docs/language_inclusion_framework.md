# Language inclusion framework

This framework governs the addition of a language or dialect to Project Tafsiri.

## Entry requirements

1. Record the language or dialect using its community-recognized identity and stable database identifier.
2. Identify qualified native speakers or linguistic experts who can review the material independently.
3. Document source provenance, collection method, consent, license, and any access restrictions.
4. Keep machine-generated candidates unverified until a human review decision is recorded.
5. Preserve dialect-specific forms. Do not fill gaps with words from another dialect or invent an umbrella form.
6. Use a verified native equivalent when available, an established borrowing when documented, or the original term with a natural explanation when no equivalent is known.
7. Treat uncertainty as unresolved evidence rather than a translation result.

## Acceptance evidence

Inclusion requires auditable source records, reviewer attribution, review status, and reproducible evaluation appropriate to the intended use. A configuration entry or generated word list alone does not establish support.

## Change control

New schema is introduced through versioned Supabase migrations after inspection of the current schema. Existing tables and reviewed data cannot be dropped or destructively altered without explicit approval.

## Repeatable onboarding gates

The [multilingual amendment](research/multilingual-architecture-amendment-001.md) extends these principles. Luhya is the reference implementation, with initial model research intended for approved Luwanga resources. The following gates use the same source, evidence, review and canonical pipeline for every language. Each decision records responsible actor, scope, evidence, policy version, date, restrictions and unresolved questions. Passing a gate never automatically passes the next.

| Gate | Required evidence and accountable decision | Exit condition |
|---|---|---|
| 1. Identity registration | Registry steward and community experts document recognized name, existing UUID or proposed opaque key, alternative names, optional supported codes, varieties and classification uncertainty | Reviewed identity proposal; no duplicate registry or forced parent |
| 2. Community and linguistic expertise | Research administrator records community participation, qualified native/expert reviewers, competence scope, conflicts and consent/compensation arrangements | Independent review capacity approved; self-report alone is insufficient |
| 3. Source registration | Source steward records work/version, exact artifact hashes/acquisitions, access restrictions and literal language/variety mentions | Auditable provenance; unresolved labels preserved |
| 4. Rights and consent | Authorized rights steward records explicit use policies, evidence, expiry and restrictions for each source version | Intended ingestion/review use allowed; unknown rights block that use |
| 5. Governed ingestion | Research operator validates parser and language profile versions, original text/locators, checksums, dry-run and idempotency | Existing import/evidence contract passes; no automatic canonical records |
| 6. Evidence review | Qualified reviewers verify source representation, language/variety scope, uncertainty and contradictions | Attributed decisions retained with machine/import origin unchanged |
| 7. Canonical knowledge | Scoped canonical approver reviews proposal, exact revisions, evidence set and conflicts | Explicit atomic promotion through approved workflow; no promotion until lexical workflow exists |
| 8. Dataset approval | Dataset steward and rights reviewer approve immutable manifests, purpose, split/leakage audit, consent and source-use policies | Explicit dataset permission for the intended research; canonical status alone insufficient |
| 9. Model research eligibility | Research lead approves bounded experiment, dataset/model rights, reproducibility contract and collaboration terms | Experiment authorized; no production support claim |
| 10. Independent evaluation | Independent qualified evaluators apply preregistered protocol per direction/variety/domain and report limitations | Documented result and release decision; absence of evidence remains absence |
| 11. Commercial eligibility | Rights authority and release operators separately review commercial clearance, exact model digest, service scope, tenant/security and operations tests | Explicit production approval where authorized; research-only assets remain excluded |

Suspension or rights revocation propagates to affected dataset/model/release decisions. It does not erase source evidence or automatically revoke unrelated language permissions. Identity lifecycle (`PROPOSED`, `UNDER_REVIEW`, `RESEARCH_ENABLED`, `SUSPENDED`, `RETIRED`) is distinct from training and commercial eligibility. No lifecycle backfill occurs automatically for existing Luhya rows.

## Hypothetical Dholuo architecture test

This is a paper scenario only: no Dholuo material is imported, vocabulary generated, registry row inserted or translation support claimed. Do not assign a code, parent or variety classification without suitable evidence and community review.

1. A community partner proposes a Dholuo identity and documented varieties. Stewards check existing `languages`/`dialects` for duplicates and record contested classifications as assertions.
2. A hypothetical bilingual work supplies two language scopes and potentially unresolved source labels. Register it once with version/artifact lineage, rather than in a second language-specific ingestion system. Until permission is established, its review/training use remains blocked.
3. After separately approved rights and reviewer qualification, a future profile would configure the existing runner's headword/gloss languages, normalization, POS mappings and optional morphology features. Do not inherit Luhya noun-class assumptions or English-gloss heuristics without validation.
4. Evidence enters the existing located-evidence workflow. A Luwanga-only reviewer cannot view restricted Dholuo tasks. A visually matching word creates no cognate, lexical identity or concept equivalence automatically.
5. Any later canonical proposal needs its own scoped approval and source attestations. A dataset would still need training rights, split controls and approval; an evaluated research model would still need commercial clearance and production authorization.

The scenario exposes current implementation gaps: language-only source/evidence targets, reusable profiles, approved qualification enforcement and generalized evaluation target types. Those are future extensions identified in the [audit](research/multilingual-readiness-audit-001.md), not features already activated. The same gates also apply when adding a new Luhya variety.
