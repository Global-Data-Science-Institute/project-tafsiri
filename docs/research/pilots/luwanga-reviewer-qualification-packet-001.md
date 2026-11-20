# Luwanga reviewer qualification packet 001

Blank evidence template for private completion. No person is nominated, qualified, consented, provisioned or granted authority by this packet. Portal participation, source provision, organizational affiliation and previous rule-pilot approval are insufficient.

| Required evidence | Private record to complete | Current status |
|---|---|---|
| Identity binding | Existing contributor identity, authenticated individual identity verification and reviewer-profile linkage if applicable | Not supplied for this pilot |
| Luwanga competence | Native/community experience or linguistic expertise, exact variety, relevant lexical/orthographic domains, supporting work or independently assessed competence; evaluator and date | Not supplied |
| Independent assessment | Evaluator's qualification, evidence reviewed, limitations, conflicts and signed decision | Not supplied |
| Research responsibility | Named responsible research lead, task authorization, accountable institution/community process | Not supplied |
| Consent and privacy | Task-specific consent, attribution preference, compensation arrangement, retention/withdrawal terms, private storage authorization | Not supplied |
| Proposal independence | Proposer contributor ID versus approver contributor ID; conflict declaration; independent source/claim judgment | Not established |
| Canonical role | Existing active CANONICAL_APPROVER contributor role, compatible dialect and LEXICAL domain; grant evidence | Not established for this pilot |
| Scope and operations | Exact Luwanga UUID and each required action:table key; explicit exclusions | Not issued |
| Qualification validity | Competence reference, finite valid_from/valid_until, issuer, review interval and revocation procedure | Not issued |
| Principal and access | Individual login-to-contributor binding, controlled membership, TLS/access configuration and credential custodian | Not provisioned; outside assignment |
| Decision attestation | Approver signature/date, exact evidence digest, source-fidelity confirmation, scope and contradiction assessments | No proposal exists |

Competence must cover the actual task, including historical interpretation or borrowing claims where selected. If no suitably qualified independent reviewer is available, defer the claim. Do not widen a dialect qualification to all Luhya varieties or a parent language. An administrative research role grants no linguistic competence by itself.

Migration 012 reuses `contributor_roles` and freezes contributor/role identity in private `lexical_governance.authorities`; exact scope, operation keys, original/current validity and revocation all matter. `principals` binds PostgreSQL session_user to contributor identity. Reassigning a legacy role must not transfer a qualification. The approver must differ from the requester; no supplied actor UUID, JWT claim, portal membership or shared owner login can replace that check. Authorities are owner-issued only after evidence review, not by this template.

An independent reviewer and canonical approver may be the same qualified person only if both responsibilities are documented and that person is independent of the proposer. When they differ, preserve both judgments privately. The source verifier may establish accurate transcription without establishing the claim's lexical correctness. Record these roles separately even when one individual performs more than one permitted task.

Before each future review/approval/execution, recheck active principal, active role, exact scope/operations, unexpired qualification and revocation. Suspend affected work immediately when revoked; preserve historical decisions and investigate completed claims separately. No qualification or credential changes are performed now. The absence of hosted 012 means no live 012 authority can currently be inspected or used; this is not proof that no competent people exist.

The existing portal's dictionary-entry evaluation model and frozen HE001 assignments remain unchanged. A future lexical review UI needs the separately reviewed extension in [the portal design](../multilingual-reviewer-portal-design-001.md); meanwhile this packet defines evidence requirements, not a second reviewer application or automatic access path.
