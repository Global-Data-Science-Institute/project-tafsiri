# Conflict-aware PR and migration integration plan

Snapshot: 2026-11-22. Exact branch names, full head/base commits, mergeability and check URLs are in [pr-stack.json](pr-stack.json). All #22–#29 were open/draft and GitHub reported MERGEABLE against their immediate bases at inspection. Mergeability is time-sensitive, not approval.

| PR | Head commit (short) | Base | Checked CI |
|---|---|---|---|
| #22 multilingual architecture | a5b45af | staging | portal/research/database success |
| #23 migration 011 lexical core | b700283 | staging | portal/research/database success |
| #24 lexical promotion | fa986c8 | #23 branch | portal/research/database success |
| #25 Luwanga pilot preparation | 646ef40 | #24 branch | No Tafsiri CI shown on this head; do not infer validation from Vercel comments |
| #26 multilingual foundation | e939479 | #25 branch | portal/research/database success |
| #27 platform architecture | 4c3253f | #26 branch | No Tafsiri CI shown on this head |
| #28 Data Studio | 83f0b33 | #27 branch | studio/portal/research/database success |
| #29 partner RC | 1d79628 | #28 branch | studio/portal/research/database success; run 44999808368 |

Local `staging` was `199a63530e447db169ba4e39c61da5239f52dcf1`; compare with freshly fetched remote refs before any integration. `git merge-base --is-ancestor a5b45af b700283` succeeded: **#23 already contains #22**, despite both PRs targeting staging. Every subsequent head descends from the previous head. The non-checkout command `git merge-tree --write-tree staging feature/tafsiri-partner-rc-001` returned tree `729a45f1d620a2a81023aafbe21cc62e253e6a15` without conflicts. No branch was merged or moved by that check.

## Proposed integration, never automatic

1. Review each logical PR once, but do not cherry-pick/squash the full ancestor stack repeatedly. Preserve original commit ancestry. The preferred candidate is the reviewed descendant of #29 plus this validation PR and separately reviewed security remediation.
2. Fetch exact remote refs and record new head/base SHAs. Verify ancestry for #22 through the candidate; re-run merge-tree against the intended integration base. If any head diverged or conflict appears, stop, create an isolated integration branch, resolve only with owner review, and rerun all checks. A stale MERGEABLE result is insufficient.
3. After explicit integration authorization, create **one integration PR** from the reviewed descendant to staging with preserved history. Do not independently squash #22 and then replay #23's copy of #22. Alternatively merge in ancestor order with ancestry-preserving merges and retarget descendants carefully; close superseded ancestor PRs only after maintainers verify their commits are included.
4. Current task authorizes neither this integration nor closing existing PRs. Initial synthetic deployment need not merge into the research staging branch: a separate protected project can deploy the approved exact descendant commit. Do not change existing production/staging branch routing.
5. Require all four CI jobs on the exact integrated candidate, plus the real scanner evidence for its scanner code/image and independent security acceptance. Documentation-only #25/#27 lacking their own Tafsiri CI is covered by a full descendant run, not silently presented as individual success.

## Migration sequence and byte identity

Apply the **sixteen files in `migrations.sha256` order** to an empty new database. The first eleven match the history through source artifact foundation; the remaining files add lexical core, promotion governance, multilingual foundation, private Studio and RC controls. No new application migration is introduced by this validation packet. Baseline migrations alone do not close S01–S03; any remediation migration must be generated with the pinned CLI, reviewed, checksummed and appended to an updated approved manifest.

Hashes use canonical Git blob LF bytes at `1d796289ba9077aa3f194fcb285bb6bf64b0580d`, not Windows CRLF checkout bytes. `python tests/studio/staging_manifest.py` verifies the baseline and normalized local copies. Export deployment files with LF and compare SHA-256 before using them. Do not change already applied migration history or silently regenerate checksums after approval.

Pinned repo Supabase CLI is 2.114.0; no automatic CLI v3 upgrade is part of this plan. Review its installed `migration list --help`, `db push --help`, and the target-only dry run before future execution. The live staging inspection showed only migrations through 010; do not apply this stack there. New project migration execution is separately authorized and must explicitly verify the new ref rather than relying on a pre-existing CLI link.

Before apply: verify empty new-project history, approved platform-managed schemas, DB snapshot/restore plan, target ref and every checksum. Apply in order, capture history/results, run private-RLS/grants/worker/function/Storage checks and legacy remediation tests. On failure, stop; compare history and actual objects. Prefer discarding and recreating the newly provisioned empty synthetic target only under its teardown authorization, or a reviewed forward fix. Never reset an existing research project, mark failed migrations applied, or use destructive down migrations to force a green check.
