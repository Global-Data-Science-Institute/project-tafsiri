PROJECT TAFSIRI

Purpose:
Low-resource Luhya language AI system supporting
English ↔ Luhya
Swahili ↔ Luhya
and dialect-aware language processing.

CORE LANGUAGE RULE:

Never invent a Luhya translation simply because an English
concept lacks a lexical equivalent.

If a verified native equivalent exists:
    use it.

If an established borrowed term exists:
    use it.

If no established equivalent exists:
    preserve the original term and explain the concept
    naturally in the requested dialect.

If uncertain:
    do not guess.

DIALECT POLICY:

Lutsotso, Bukusu, Luwanga, Maragoli, Isukha, etc.
must remain first-class dialects.

Do not create an artificial generalized "Luhya" vocabulary
by blending dialects.

DATA POLICY:

Human verified data outranks machine-generated data.

Machine-generated translations must never automatically
become verified training data.

DATABASE POLICY:

Never drop or destructively alter existing Tafsiri tables
without explicit approval.

All schema changes must be implemented as versioned
Supabase migrations.

Always inspect the existing schema before proposing
new structures.