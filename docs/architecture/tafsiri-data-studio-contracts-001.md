# Data Studio collection contracts 001

Version: `studio-v1`. All requests are authenticated with exact organization/project authorization. `/api/studio` provides GET state and POST commands; `/api/studio/upload` provides bounded multipart upload and authenticated download by upload ID; `/api/studio/assist` performs provider admission/processing/completion. JSON responses are no-store. Session mutations require the configured application origin. Database authorization is authoritative even for direct RPC calls. Streaming request limits enforce actual bytes, not just Content-Length.

Commands use an operation name, request UUID and JSON payload. Contribution writes include expected revision. Same request UUID/body retries return the stored result; different bodies conflict. Unknown fields with privilege implications (owner, verified status, canonical ID) are never used to establish authority. Resource-not-found and not-owned share denial semantics. Errors use safe codes, never source text or internal database details.

| Command | Input → output | Authority / validation |
|---|---|---|
| onboard | institution name, admin email → organization shell and private invitation | Finite GDSI onboarding authority; no partner content access |
| accept_invitation | private token → exact membership | Current verified Auth email, unexpired/unrevoked/single-use token; cross-org collaboration grants only the named project |
| invite / revoke_invitation / revoke_member | org/project, email/role or target ID → attributed access decision | Org admin or exact-project PI; project authority cannot create org administrators |
| update_org | profile name/description → profile | Own org admin |
| propose_language | org, name, description → proposal | Active organization or exact project member; original label retained, no registry insert |
| process_language | proposal ID, decision → proposal state | Studio admin; COLLECTION_ALLOWED or REJECTED only |
| create_project | org/title, proposal OR language/variety identity → project | Own org admin; same-org processed proposal or existing shared identity |
| create_campaign | project, title, category, questions, target → campaign | Exact-project PI; bounded template labels/keys/required flags |
| project_settings | project, external_ai boolean → policy | Exact-project PI; never overrides item consent/server enablement |
| save | item ID or new ID, project/category, original text/context/source/method/counterpart label, consent map, expected revision → draft | Owner; active project; strict size/type fields and no submitted rewrite |
| submit | item ID, expected revision → SUBMITTED | Owner; required content/scope/consent; snapshot event sealed |
| transition | item ID, expected revision, next status, reason → queue status | Admin; finite state machine, no verification/training grants |
| withdraw | item ID, expected revision, reason → WITHDRAWN | Owner; blocks processing/access and prepared handoff |
| correction | item ID, reason → audit request | Owner; accepted original unchanged |
| assist_begin / server-only studio_ai_finish | item ID, workflow, mock/openai → attributed run and separate unverified suggestion | Own contributor or project research role, current access/consent, bounded actor/project quota; server-only completion rechecks state |
| upload_intent | item ID, MIME, size, SHA-256 → random private path | Owner/editable item; bounded type/size; quarantine only |
| prepare_handoff | item ID → immutable PREPARED_BLOCKED packet | Admin; accepted current consent; source registration and reviewer gates still closed |

Original representation fields include text, translation, counterpart label, context, source reference and collection method. Consent fields are booleans for internal_research, human_review, training, public_display, redistribution, commercial, external_ai, plus a fixed consent version. Supplied scope is the project's existing identity or original language proposal; multi-endpoint labels are retained but unverified. All records are synthetic for this milestone.

The handoff packet names contribution/revision/campaign and project scope, original content, consent assertions and quarantine upload IDs/checksums. Events link its originating contribution and actor. It carries `human_verified=false`, `canonical_approved=false`, `training_approved=false`, `commercially_cleared=false`, and `reviewer_handoff=BLOCKED_PENDING_AUTHORIZED_INTEGRATION`. These flags cannot be client overridden. Existing source/artifact IDs are created only by a separately authorized registration workflow, then linked back to the packet. Consent assertions alone cannot satisfy independent rights review. Signing/export digest and actual reviewer task creation remain deferred.

Future collection types and external adapters require a new reviewed contract version. Original snapshots remain immutable; corrections create new revisions/requests. No offline synchronization is implemented. Pending uploads remain quarantined until a future scanner/registration process explicitly admits them; a file extension or client MIME alone is not safety evidence.
