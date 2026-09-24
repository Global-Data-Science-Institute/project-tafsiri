# Tafsiri Evidence Promotion & Canonical Rule Governance 001

## Status

Architecture status: **ready to design Migration 009 SQL**. This document creates no schema, promotes no evidence, and performs no database or production writes.

## 1. Executive summary

Tafsiri will preserve five separate decisions:

```text
SCHOLARLY OR COMMUNITY SOURCE
  -> EXTRACTED EVIDENCE
  -> HUMAN-VERIFIED EVIDENCE
  -> EXPLICIT PROMOTION DECISION
  -> VERSIONED CANONICAL RULE
  -> OPTIONAL RUNTIME DEPLOYMENT
```

Evidence verification establishes fidelity to a source. Promotion establishes Tafsiri's governed acceptance of a bounded linguistic assertion. Runtime approval establishes that an operational implementation has passed separate evaluation. No transition is automatic.

Migration 009 should establish a minimal, append-oriented canonical rule and promotion foundation. Typed G2P, tone, morphology, runtime, and test-case structures should follow after the first promotion pilot establishes their actual recurring requirements.

## 2. Governance principles

1. Verified evidence is not canonical knowledge.
2. Canonical knowledge is created only by an authorized, explicit promotion.
3. Canonical semantic content is revisioned and never silently overwritten.
4. Dialect scope is explicit; similar spellings or related patterns do not establish a shared rule.
5. Contradictory evidence remains visible and traceable.
6. Academic, native-speaker, fieldwork, community, and corpus evidence retain distinct provenance without an automatic authority hierarchy.
7. Canonical status does not imply runtime eligibility.
8. Every canonical revision traces through a promotion and evidence links to source locators.
9. Variation is represented with scope and conditions rather than normalized away.
10. Governance storage is separated from public serving projections.

## 3. Evidence and canonical-rule boundary

`linguistic_evidence.verification_status = VERIFIED` means that the evidence record accurately represents the cited source. It does not assert that Tafsiri adopts the claim, that competing claims do not exist, or that the claim is safe to execute.

Promotion must specify the accepted statement, scope, conditions, evidence set, policy version, authority, rationale, and intended action. Even unanimous, peer-reviewed, high-confidence evidence remains noncanonical until an approved promotion is applied.

## 4. Rule identity model

`linguistic_rules` is the stable identity table. Recommended fields:

| Field | Purpose |
|---|---|
| `id` | UUID identity |
| `rule_key` | Stable, human-readable governed key; unique and immutable |
| `rule_type_id` | Separate canonical taxonomy |
| `canonical_scope` | `DIALECT`, `MULTI_DIALECT`, `FAMILY_GENERALIZATION`, or carefully governed `PROTO_LANGUAGE` |
| `lifecycle_status` | `PROVISIONAL`, `ACTIVE`, `DISPUTED`, `DEPRECATED`, `SUPERSEDED` |
| `current_revision_id` | Current approved semantic revision |
| `created_by_promotion_id` | Promotion that created the identity |
| timestamps | Creation, deprecation, and supersession audit |

Statement text is never identity. `ACTIVE` means approved canonical knowledge. `PROVISIONAL` permits bounded canonical use where governance accepts remaining uncertainty. `VERIFIED` is reserved for evidence review and is not a rule status.

## 5. Rule revision model

`linguistic_rule_revisions` owns semantic content:

- rule and monotonically increasing revision number
- canonical human-readable statement
- scope and concise condition/exception summaries
- structured-representation version marker, without a universal JSON-only rule language
- effective date, deprecation date, and reason
- policy version and creating promotion
- immutable creation audit

A correction creates revision `n+1`; revision `n` remains addressable. Only an applied promotion may advance `current_revision_id`. The database must reject two revisions with the same `(rule_id, revision_number)` and prevent a current revision from belonging to another rule.

## 6. Canonical rule taxonomy

Use a separate governed `linguistic_rule_types` table. Evidence types describe scholarly observations; canonical types describe governed Tafsiri assertions and later specialization/runtime needs.

Initial taxonomy values may include:

- Phonology: `PHONOLOGY`, `GRAPHEME_PHONEME`, `ALLOPHONY`, `TONE`, `PROSODY`, `SYLLABLE_STRUCTURE`, `MORPHOPHONOLOGY`
- Morphology: `NOUN_CLASS`, `AGREEMENT`, `INFLECTION`, `DERIVATION`, `VERB_MORPHOLOGY`, `TENSE_ASPECT`, `NEGATION`
- Grammar: `LEXICAL_CATEGORY`, `SYNTAX`, `WORD_ORDER`, `ARGUMENT_STRUCTURE`
- Meaning: `SEMANTICS`, `PRAGMATICS`, `MODALITY`
- Other: `IDEOPHONE`, `LOANWORD_ADAPTATION`, `TERMINOLOGY_PRINCIPLE`, `DIALECT_VARIATION`

The canonical taxonomy has stable keys, descriptions, active/deprecated state, and replacement metadata. Evidence-to-rule mapping is policy, not a foreign-key equivalence.

## 7. Dialect scope model

`linguistic_rule_dialects` links a rule revision to canonical dialects with roles:

- `APPLIES_TO`
- `CONTRASTS_WITH`
- `EXCEPTION`
- `SUPPORTED_VARIETY`

Revision-level ownership permits scope to change without rewriting history. `DIALECT` requires one `APPLIES_TO` link. `MULTI_DIALECT` requires at least two. `FAMILY_GENERALIZATION` may have supporting-variety links but must not imply automatic applicability to every Luhya variety.

`PROTO_LANGUAGE` may be retained for canonical historical/reconstructive knowledge, but it is always runtime-ineligible for modern-dialect production unless a separate modern rule is promoted. No Proto-Luyia dialect row is created.

## 8. Evidence-link model

`linguistic_rule_evidence` is revision-to-evidence many-to-many with roles:

- `SUPPORTS`
- `CONTRADICTS`
- `QUALIFIES`
- `EXCEPTION`
- `HISTORICAL_SUPPORT`

Active/provisional revisions require at least one `SUPPORTS` link to verified evidence under the default policy. Disputed evidence may be attached in non-supporting roles. Supporting evidence that is later disputed does not disappear; it triggers governance review and may move the rule to `DISPUTED` or lead to a revision.

Evidence provenance remains unchanged. Promotion does not clone evidence content into canonical history beyond the concise canonical statement and evidence-set checksum.

## 9. Promotion model

`linguistic_rule_promotions` records one explicit governance action:

- stable `promotion_key` and unique idempotency key
- action: `CREATE_RULE`, `CREATE_REVISION`, `DEPRECATE_RULE`, `SUPERSEDE_RULE`, `DISPUTE_RULE`, `REACTIVATE_RULE`
- target or proposed rule key/type/scope
- proposed canonical statement and condition/exception summaries
- deterministic evidence-set checksum
- policy version and risk class
- requested by/at, approved by/at, rationale
- status and failure/application audit
- separation-of-duties policy selected for this promotion

There is no generic `UPDATE` action. A promotion becomes immutable after approval except for controlled status transitions and application audit.

## 10. Promotion lifecycle

Use `DRAFT -> READY_FOR_REVIEW -> APPROVED -> APPLIED`, with terminal alternatives `REJECTED` and `WITHDRAWN`. `APPROVED` and `APPLIED` remain separate:

- `APPROVED`: an authorized governance decision exists.
- `APPLIED`: the approved transaction successfully created its recorded outputs.

An approved promotion that fails application stays approved and records the failure; retry uses the same idempotency key. Application cannot modify the approved proposal.

## 11. Promotion outputs

`linguistic_rule_promotion_outputs` records typed outputs with an ordinal and referenced identity:

- `RULE_CREATED` or `RULE_REUSED`
- `REVISION_CREATED`
- `EVIDENCE_LINK_CREATED`
- `DIALECT_LINK_CREATED`
- `RULE_DEPRECATED`
- `SUPERSESSION_CREATED`
- `CURRENT_REVISION_ADVANCED`

Outputs make retries auditable and allow a single split or merge promotion to record several rules and supersession edges. Foreign-key enforcement should be used where practical; a polymorphic output should include strict type validation and immutable identifiers.

## 12. Approval authority

Add explicit authority rather than infer it from contributor name, email, or Reviewer Portal role. A future `contributor_roles` foundation should include contributor, governed role, optional dialect/domain scope, grantor, validity interval, status, and audit.

Initial roles:

- `LINGUISTIC_REVIEWER`
- `SENIOR_LINGUISTIC_REVIEWER`
- `RESEARCH_ADMIN`
- `CANONICAL_APPROVER`

Qualification is operational: native-dialect expertise, linguistic training, domain expertise, source familiarity, demonstrated community authority, or research administration may establish scoped authority. Academic credentials alone do not confer universal linguistic authority.

## 13. Review thresholds by risk

| Risk class | Default threshold | Separation policy |
|---|---|---|
| Descriptive, low risk | At least one verified evidence item; one scoped canonical approver; explicit dialect/scope review | `SINGLE_RESEARCHER_ALLOWED` with declared rationale |
| Operational language rule | Prefer two independent evidence items or one source plus qualified native-speaker/fieldwork confirmation; specialist review; conditions and exceptions reviewed | Separate verifier and approver when feasible; exception requires research-admin rationale |
| High impact | Multiple independent evidence records, source diversity, relevant dialect specialist, senior/canonical approval, explicit contradiction and exception review | `SEPARATION_REQUIRED` |

G2P, allophony, tone assignment, translation-generation behavior, terminology principles, and broad multi-dialect generalizations are at least operational and may be high impact depending on use. Threshold exceptions are recorded, never implicit.

## 14. Contributor and authority model

Keep `contributors` as human identity. Add governed role definitions and time-bounded role assignments. Role scope may include a dialect, rule domain, or project-wide administration. Revocation prevents future approvals but does not erase historical decisions.

Migration 009 should include this minimal authority foundation because approval validation cannot safely rely on email or application roles. Reviewer Portal authorization remains separate.

## 15. Multiple-reviewer model

Recommend a future `linguistic_evidence_reviews` history table while retaining `linguistic_evidence.reviewed_by/reviewed_at` as current summary fields. History fields:

- evidence and reviewer
- decision: `CONFIRM`, `REJECT`, `DISPUTE`, `NEEDS_REVISION`
- optional confidence and expertise scope
- concise notes, policy version, and timestamp
- withdrawal/supersession audit

Migration 009 may defer this table because the current 110-row review is already auditable, but promotion policy must allow evidence-review history to become a prerequisite for higher-risk rules.

## 16. Contradictory evidence

No automatic winner is selected. Conflict review classifies disagreement as scope split, historical change, speaker/region/register variation, competing analysis, or unresolved dispute. Both evidence chains stay linked.

Possible outcomes include a narrower revision, two dialect/context-specific rules, a `DISPUTED` rule, a provisional rule with stated limitations, or no promotion. Contradictory evidence may attach with `CONTRADICTS`; qualifying and exception evidence remain first-class inputs.

## 17. Variation handling

Canonical statements may be conditioned by geographic variety, speaker group, age, register, phonological environment, morphological context, or lexical class. The first foundation stores concise condition and exception summaries plus dialect links. It must not claim a single normalized form when reviewed evidence documents variation.

## 18. Structured rule representation

Use a hybrid design:

- immutable human-readable canonical statement in each revision
- normalized condition and exception rows where generally useful
- later domain-specific child tables for validated operational structures

A universal JSON blob must not be the only structured representation. A bounded `structured_parameters` JSON column may be permitted as versioned supplemental data during pilots, but no runtime consumer may depend on ungoverned keys.

## 19. Rule conditions

Include `linguistic_rule_conditions` in Migration 009 because conditions are essential to avoid overgeneralizing even the first G2P/allophony pilot. Fields include revision, condition type, concise value/statement, order, negation flag, and optional dialect link.

Initial types: `PHONOLOGICAL_ENVIRONMENT`, `MORPHOLOGICAL_CONTEXT`, `SYNTACTIC_CONTEXT`, `SEMANTIC_CONTEXT`, `REGISTER`, `DIALECT_VARIANT`, `SPEAKER_VARIATION`, `LEXICAL_EXCEPTION`.

## 20. Exceptions

Defer a specialized `linguistic_rule_exceptions` table until exception patterns are measured. Migration 009 uses revision exception summaries, condition rows with `LEXICAL_EXCEPTION`, and evidence links with role `EXCEPTION`. No premature foreign key to a future lexical core is added.

## 21. G2P implications

The future `canonical_g2p_rules` table should be revision-owned and contain grapheme, phoneme, optional allophone, environment, ordering/priority, boundary context, and exception behavior. It remains governed data, not executable code. Add it after the pilot has reviewed ordering, Unicode normalization, and interaction requirements.

## 22. Tone-rule implications

Tone must not be forced into G2P. A later tone model may represent underlying tone, melody, tone-bearing unit, morphological domain, trigger/target, direction, and spreading, shifting, deletion, or docking operations. Migration 009 stores descriptive tone revisions and conditions only. Initial tone candidates remain runtime-ineligible.

## 23. Morphology implications

The foundation supports canonical morphology statements, dialects, conditions, evidence, and revisions. Typed noun-class, concord, derivation, inflection, verbal extension, TAM, negation, and morphophonology tables are deferred until promoted use cases demonstrate common structures. Migration 009 is not a morphology engine.

## 24. Runtime eligibility

Runtime governance is separate and must not use an `is_executable` boolean. A later deployment entity records rule revision, target implementation, state (`NOT_EVALUATED`, `TESTING`, `APPROVED_FOR_RUNTIME`, `DISABLED`, `RETIRED`), approval, evaluation artifact, version, and dates.

Canonical descriptive rules default to `NOT_EVALUATED`. Proto-language rules are not eligible for modern production behavior directly.

## 25. Runtime testing and evaluation

Later `linguistic_rule_test_cases` may store revision, input, expected output, context, dialect, provenance/source, status, and test-set partition. Operational rules require tests before runtime approval; descriptive semantic rules need not have executable test cases.

Evaluation uses scholarly examples, native-speaker examples, dictionary forms, and held-out data. Test material preserves rights and provenance. Evaluation results never rewrite the promotion decision.

## 26. Versioning, supersession, split, and merge

`linguistic_rule_supersessions` records directed old-rule to new-rule edges, rationale, and promotion. It never deletes either rule.

- Semantic correction: new revision of the same identity.
- Replacement by a different assertion: supersession edge.
- Split: one old rule to two or more new rules.
- Merge: two or more old rules to one new rule.

Cycles are forbidden. Old revisions, evidence links, promotions, dates, and rationales remain queryable.

## 27. Idempotency and transactionality

An application transaction must:

1. lock and validate the approved promotion;
2. verify authority, policy version, status, evidence checksums, and evidence states;
3. create or reuse the stable rule identity;
4. create the immutable revision;
5. attach evidence, dialects, and conditions;
6. apply lifecycle/supersession changes;
7. record all outputs;
8. mark the promotion `APPLIED` and commit.

Any failure rolls back. Unique promotion/idempotency keys, evidence-set checksum, rule key, revision number, evidence links, dialect links, and output identities prevent duplicate application.

## 28. Audit chain

The mandatory path is:

```text
rule -> current or historical revision -> applied promotion
     -> evidence link -> verified evidence -> source version
     -> scholarly/community source -> exact source locator
```

Authority assignments, approval rationale, policy version, conditions, contradictions, supersession edges, and runtime decisions are additional immutable audit branches.

## 29. RLS, security, and serving separation

All governance tables begin deny-by-default with RLS enabled:

- `service_role`: controlled reads and writes
- authorized researcher/admin access: future explicit API or narrowly scoped policies
- `anon` and ordinary `authenticated`: no direct table access
- Reviewer Portal: no access during this phase

Canonical rules eventually reach public products through reviewed serving projections or APIs containing only current eligible data. Governance tables, evidence-review records, promotion deliberations, identities, and internal notes are not public serving surfaces.

## 30. First canonical pilot candidates

No candidate is promoted by this design. The following narrow candidates are suitable for a future promotion exercise:

| Candidate | Evidence key | Scope | Proposed canonical domain |
|---|---|---|---|
| Lubukusu `kh` represents /x/ | `LE001_ABCB2C63153BCC387A919A04` | Bukusu | `GRAPHEME_PHONEME` |
| Lubukusu `b` realizes [β] outside post-nasal context | `LE001_C96884B0E4BCEB6B99AF0245` | Bukusu | `ALLOPHONY` |
| Luwanga /a+a/ coalescence with length | `LE001_B615C6C88A7506D3529CEA5B` | Luwanga | `MORPHOPHONOLOGY` |
| Lubukusu verb-to-adjective `-e` derivation | `LE001_7516ACA55554B7B091DF4F15` | Bukusu | `DERIVATION` |
| Lubukusu adjective-to-verb `-a` derivation | `LE001_524FA34A0840CD97D329DF7F` | Bukusu | `DERIVATION` |
| Lubukusu attributive adjective noun-class agreement | `LE001_0D4EF03C6F050473B8EAE121` | Bukusu | `AGREEMENT` |
| Kisa word-final long vowels in interjections | `LE001_82B9329A5AC296B2F491DB3D` | Kisa | `PHONOLOGY` |
| Lwidakho loan bilabial stops may adapt as [β] | `LE001_37D66294BFE25A3DD410613E` | Idakho | `LOANWORD_ADAPTATION` |

The two Lubukusu pronunciation candidates are useful but operational, so native-speaker confirmation, exception review, and runtime test design are required before runtime approval.

## 31. Pilot readiness dimensions

Use independent descriptive dimensions: `EVIDENCE_COUNT`, `SOURCE_DIVERSITY`, `REVIEW_COMPLETENESS`, `DIALECT_SCOPE_CLARITY`, `CONDITION_CLARITY`, `CONTRADICTION_STATUS`, and `RUNTIME_TESTABILITY`. Values are `CLEAR`, `PARTIAL`, `INSUFFICIENT`, or `NOT_APPLICABLE`; no composite score is calculated.

| Candidate group | Evidence count | Source diversity | Review | Scope | Conditions | Contradiction | Testability |
|---|---|---|---|---|---|---|---|
| Lubukusu `kh` | CLEAR (1) | INSUFFICIENT | CLEAR | CLEAR | CLEAR | CLEAR: none recorded | CLEAR |
| Lubukusu contextual `b` | CLEAR (1) | INSUFFICIENT | CLEAR | CLEAR | PARTIAL: exceptions need review | CLEAR: none recorded | CLEAR |
| Luwanga coalescence | CLEAR (1) | INSUFFICIENT | CLEAR | CLEAR | PARTIAL | CLEAR: none recorded | CLEAR |
| Lubukusu derivation/agreement | CLEAR (1 each) | INSUFFICIENT | CLEAR | CLEAR | PARTIAL | CLEAR: none recorded | PARTIAL |
| Kisa interjection length | CLEAR (1) | INSUFFICIENT | CLEAR | CLEAR | CLEAR | CLEAR: none recorded | CLEAR |
| Lwidakho loan [β] | CLEAR (1) | INSUFFICIENT | CLEAR | CLEAR | PARTIAL | CLEAR: none recorded | PARTIAL |

`CLEAR: none recorded` means Extraction 001 contains no linked contradiction; it is not proof that contrary evidence does not exist.

## 32. Minimum Migration 009 scope

Recommended name: **Canonical Linguistic Rule & Promotion Governance Foundation**.

Minimum tables:

1. `linguistic_rule_types`
2. `linguistic_rules`
3. `linguistic_rule_revisions`
4. `linguistic_rule_dialects`
5. `linguistic_rule_conditions`
6. `linguistic_rule_evidence`
7. `linguistic_rule_promotions`
8. `linguistic_rule_promotion_outputs`
9. `linguistic_rule_supersessions`
10. `contributor_role_types`
11. `contributor_roles`

Migration 009 should include taxonomy seed rows, constraints, indexes, RLS, deny-by-default grants, lifecycle validation, append-oriented revision protection, authority validation hooks, and atomic promotion-application support. It should contain no canonical rules or evidence promotions.

## 33. Deferred structures

Defer:

- `linguistic_evidence_reviews`
- `linguistic_rule_exceptions`
- `canonical_g2p_rules`
- typed tone and morphology children
- runtime eligibility/deployments
- rule test cases and evaluation runs
- rule dependencies
- public serving projections
- lexical-form exception foreign keys

Dependencies are deferred because the first pilot can express prerequisites in review rationale and conditions without committing to a rule-engine graph.

## 34. Migration sequencing

1. Migration 009: canonical rule, promotion, scope, evidence, authority, condition, and supersession foundation.
2. First promotion pilot: governance artifacts and dry-run only, followed by approved narrow rule creation.
3. Typed pronunciation/G2P structures once pilot requirements are stable.
4. Canonical lexical core when lexical identities and governance are ready.
5. Typed morphology/grammar structures based on real promoted cases.
6. Runtime evaluation, deployment, and serving projections after canonical data exists.

Numbers after Migration 009 remain provisional so repository history, dependencies, and readiness determine their final order.

## 35. Example end-to-end cases

### A. Lubukusu `kh`

Verified evidence `LE001_ABCB...` enters a promotion with Bukusu scope and a canonical grapheme-phoneme statement. An authorized operational-rule approver reviews native-speaker confirmation and exceptions. Application creates a rule and revision; later typed G2P data may represent `kh -> /x/`. Runtime remains `NOT_EVALUATED` until tests pass.

### B. Lubukusu contextual `b`

Evidence `LE001_C968...` supports an allophony candidate with a negative post-nasal condition. The condition is first-class. Exception review is required before promotion and runtime testing covers nasal/non-nasal contexts.

### C. Lwisukha tone

Verified nominal-tone evidence may support a descriptive `TONE` revision scoped to Isukha. It remains canonical descriptive knowledge and runtime-ineligible until a tone-specific representation and evaluation exist.

### D. Lwidakho loanword adaptation

Verified adaptation evidence can support a bounded loanword-pattern rule. Promotion does not create a borrowed-term or terminology decision and does not license new words automatically.

### E. Ideophones across Llogoori, Lunyore, and Lutiriki

A comparative semantic rule uses `MULTI_DIALECT`, explicit links, and variety-specific qualifications. It does not become a family-wide Luhya rule.

### F. Future contradiction

A later verified source supporting a different realization attaches as `CONTRADICTS`. Governance may mark the rule disputed, narrow its context, create a new revision, or split the rule by dialect/register while preserving both source chains.

## 36. Architecture decisions

### ADR-011: Verified evidence is not canonical knowledge

**Decision:** Evidence verification records fidelity to a source only. No verification status or confidence value automatically creates canonical Tafsiri knowledge.

### ADR-012: Canonical linguistic rules require explicit promotion

**Decision:** Every canonical rule identity, revision, lifecycle change, and supersession originates from an authorized promotion with a stable key, evidence checksum, rationale, and policy version.

### ADR-013: Canonical rule revisions preserve history

**Decision:** Semantic changes create immutable numbered revisions. Prior statements, evidence links, promotions, and effective dates remain queryable.

### ADR-014: Contradictory evidence remains visible

**Decision:** Conflicting verified evidence is linked with an explicit role and never deleted or automatically resolved. Governance records whether the outcome is variation, scope split, competing analysis, or unresolved dispute.

### ADR-015: Canonical does not imply runtime enabled

**Decision:** Runtime eligibility, evaluation, approval, deployment, disablement, and retirement are separate from canonical lifecycle.

### ADR-016: Dialect scope is explicit on linguistic rules

**Decision:** Every applicable modern-language revision has explicit canonical dialect links. Family, comparative, and proto scopes never imply application to every modern dialect.

### ADR-017: Runtime validation is distinct from scholarly promotion

**Decision:** Promotion decides governed knowledge. Runtime evaluation tests an implementation against scholarly, community, dictionary, and held-out data. Either may succeed without the other.

### ADR-018: Rule provenance remains traceable to evidence

**Decision:** Each active or provisional canonical revision links through its promotion to verified supporting evidence and exact source locators. Evidence provenance is never rewritten during promotion.

### ADR-019: Human authority is explicit and auditable

**Decision:** Contributor identities do not imply authority. Time-bounded, scoped, granted roles authorize review and promotion decisions, with risk-sensitive separation policy.

### ADR-020: Variation is represented, not normalized away

**Decision:** Dialect, region, speaker, age, register, environment, and morphological context may condition canonical rules. Governance does not erase documented variation to produce a generalized Luhya form.

## 37. Open questions for Migration 009 SQL design

1. Should `current_revision_id` be nullable until a create promotion is fully applied, or should rule and first revision be inserted with deferred constraints in one transaction?
2. Should the promotion proposal use normalized child rows before approval, or an immutable versioned proposal document plus validated relational outputs?
3. Which authority scopes are required for the first pilot: domain, dialect, risk class, or all three?
4. Should a single evidence review remain sufficient for low-risk promotion while `linguistic_evidence_reviews` is deferred?
5. Which lifecycle transitions need database triggers versus a privileged transaction function?
6. How should evidence status changes after promotion trigger mandatory rule review without automatically changing canonical status?
7. Is `PROVISIONAL` necessary in the first migration, or should uncertain candidates remain unpromoted?

## 38. Final recommendation

**READY TO DESIGN MIGRATION 009 SQL**

Migration 009 should create only the governed canonical identity, revision, scope, evidence, promotion, authority, condition, output, and supersession foundation. It must seed no canonical rules, apply no promotions, and expose no governance table to public clients.
