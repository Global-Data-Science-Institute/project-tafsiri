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
