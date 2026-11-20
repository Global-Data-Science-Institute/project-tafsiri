# Tafsiri Data Studio technical architecture 001

Data Studio collects material before a corpus exists. It is an isolated `/studio` contributor/admin module in the existing Next.js application, with its own private Supabase intake schema. The existing Reviewer Portal retains qualified review; source registration, evidence and canonical decisions remain in the existing research pipeline. No legacy public submissions are used.

## MVP scope and data model

The milestone is synthetic-only and disabled by default at the application boundary. Database access additionally requires a separately provisioned, finite Studio membership. No memberships or real data are seeded by the migration. This avoids enabling collection merely by deploying an application build. Synthetic labels are visible, but self-declared synthetic text is not proof of authenticity; no external processing or automatic research ingestion is enabled.

| Private entity | Ownership and invariant |
|---|---|
| Members | Auth user, contributor/admin role, active and expiry; owner-provisioned only, no inheritance from reviewer or commercial roles |
| Language proposals | Original name/community/scope description, proposer, PENDING/COLLECTION_ALLOWED/REJECTED; processing does not insert languages/dialects/registry rows |
| Projects | Admin-created campaign name, exact existing language/variety OR processed language proposal, collection targets/template, active flag, synthetic-only, external AI disabled |
| Contributions | Owner/project/category, immutable origin ID, draft content and six independent consent choices, status, optimistic revision; server derives owner |
| Events | Append-only original submitted snapshots, draft/correction/withdrawal history, attributed decisions and request IDs; no overwriting original submitted representation |
| Uploads | Owner/item, random object path, declared MIME/size/digest, quarantine state; never a public URL or canonical source artifact |
| AI suggestions | Separate MACHINE_GENERATED/UNVERIFIED records, evidence contribution/revision, provider/model/prompt/config, elapsed time and structured output; never edits original content |
| Handoff packets | Accepted contribution snapshot/digest and consent assertions, origin links, upload references; PREPARED_BLOCKED pending existing registration/rights/qualification gates |

Categories: WORD, SENTENCE_PAIR, PROVERB_IDIOM, NARRATIVE, PRONUNCIATION, CONVERSATION, DOCUMENT, ANNOTATION, CULTURAL_CONTEXT. A versioned type key plus original representation supports future categories without modifying canonical tables. Keep headword/source and translated/gloss scope separate; unresolved language labels stay literal proposals. Categories requiring multiple endpoints must supply an explicit counterpart scope label; it remains unverified. Files preserve original bytes and text preserves Unicode; no normalization overwrites originals.

## Lifecycle and governance

DRAFT → SUBMITTED → TRIAGED → ACCEPTED_FOR_RESEARCH_INTAKE. Admins may request NEEDS_CLARIFICATION or reject SUBMITTED/TRIAGED items. Clarification allows the owner to revise and resubmit; the prior submission remains an event snapshot. Owners may withdraw before or after acceptance. Corrections to accepted items create requests; they do not rewrite the accepted snapshot. Withdrawal blocks AI, download and new handoff and marks prepared packets withdrawn. Downstream deletion/rights-impact handling remains a future operator workflow, never a claim that withdrawing erases an already-trained model.

Consent assertions independently cover internal research, human review, training, public display, redistribution and commercial use, default false. Submission requires explicit internal-research and human-review choices for this workflow. Checking training/commercial choices records a contributor assertion only, not a verified license or downstream approval. Project/item external AI authorization is separate, defaults false and cannot bypass provider support. Consent text/version and the submitted snapshot are retained. Admin intake acceptance is an administrative eligibility judgment, never linguistic verification.

## Contributor and administrator experience

Mobile-first forms select/project proposed language, category and guided original text, counterpart text/label, source, collection method and context. Explicit save/resume avoids silent local persistence of private text. History shows status, revisions, uploads, suggestions and uncertainty. Upload/capture controls enforce bounded safe types; quarantine is mandatory. Audio capture uses browser microphone permission and explicit stop/upload; a file-upload alternative works without capture support. Offline synchronization is deferred: future encrypted local drafts need device consent, revision-based conflict resolution and deletion after sync, not last-writer-wins.

Admins process language requests, create projects/campaign targets/templates, inspect scoped queues, contributor IDs/status, quarantine metadata, duplicate flags, consent and AI annotations, triage and accept, and prepare blocked research packets. Counts indicate collection progress only, never model readiness. A processed proposal remains separate from canonical identity approval.

## Isolation and integration

Every RPC requires validated Auth identity and current Studio membership. The database derives ownership, restricts contributor reads to own items/proposals and active project metadata, and uses row locks/expected revisions for writes. Only Studio admins triage or prepare packets. No caller-supplied contributor/admin flag is trusted. Private tables deny ordinary direct access; narrowly granted functions have fixed search paths and no arbitrary SQL. Storage object policies bind the exact registered upload path to current owner/admin access and contribution state; no anonymous or cross-user listing/read.

The MVP prepares an origin-preserving intake packet for the existing registration operator; it cannot create source/evidence/canonical rows or Reviewer Portal assignments. Tests assert reviewer handoff is BLOCKED_PENDING_AUTHORIZED_INTEGRATION. Future integration must register consent/rights decisions, exact artifacts/imports/entries and typed reviewer tasks through existing governed contracts. No source registry is replicated inside Studio.
