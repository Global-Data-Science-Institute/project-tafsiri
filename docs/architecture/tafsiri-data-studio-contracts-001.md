# Data Studio collection contracts 001

Version: `studio-v1`. All requests are authenticated and restricted to synthetic collection members. `/api/studio` provides GET state and POST commands; `/api/studio/upload` provides bounded multipart upload, and authenticated download uses an upload ID. JSON responses are no-store. Session mutations require same-origin requests. Database authorization is authoritative even for direct RPC calls.

Commands use an operation name, request UUID and JSON payload. Contribution writes include expected revision. Same request UUID/body retries return the stored result; different bodies conflict. Unknown fields with privilege implications (owner, verified status, canonical ID) are never used to establish authority. Resource-not-found and not-owned share denial semantics. Errors use safe codes, never source text or internal database details.

| Command | Input → output | Authority / validation |
|---|---|---|
| propose_language | name, description → proposal | Active contributor; original label retained, no registry insert |
| process_language | proposal ID, decision → proposal state | Studio admin; COLLECTION_ALLOWED or REJECTED only |
| create_project | title, proposal OR language/variety identity, targets, template → project | Admin; proposal processed or existing identity; synthetic and external-disabled |
| save | item ID or new ID, project/category, original text/context/source/method/counterpart label, consent map, expected revision → draft | Owner; active project; strict size/type fields and no submitted rewrite |
| submit | item ID, expected revision → SUBMITTED | Owner; required content/scope/consent; snapshot event sealed |
| transition | item ID, expected revision, next status, reason → queue status | Admin; finite state machine, no verification/training grants |
| withdraw | item ID, expected revision, reason → WITHDRAWN | Owner; blocks processing/access and prepared handoff |
| correction | item ID, reason → audit request | Owner; accepted original unchanged |
| assist | item ID, workflow, provider=offline → suggestion | Owner/admin; active nonwithdrawn item, bounded daily quota, synthetic only |
| upload_intent | item ID, MIME, size, SHA-256 → random private path | Owner/editable item; bounded type/size; quarantine only |
| prepare_handoff | item ID → immutable PREPARED_BLOCKED packet | Admin; accepted current consent; source registration and reviewer gates still closed |

Original representation fields include text, translation, counterpart label, context, source reference and collection method. Consent fields are booleans for internal_research, human_review, training, public_display, redistribution, commercial, external_ai, plus a fixed consent version. Supplied scope is the project's existing identity or original language proposal; multi-endpoint labels are retained but unverified. All records are synthetic for this milestone.

The handoff packet names contribution/revision/project/scope, original content, consent assertions, quarantine upload IDs/checksums and origin event references. It carries `human_verified=false`, `canonical_approved=false`, `training_approved=false`, `commercially_cleared=false`, and `reviewer_handoff=BLOCKED_PENDING_AUTHORIZED_INTEGRATION`. Those flags cannot be client overridden. Existing source/artifact IDs are created only by a future separately authorized registration workflow, then linked back to the packet. Consent assertions alone cannot satisfy its independent rights review.

Future collection types and external adapters require a new reviewed contract version. Original snapshots remain immutable; corrections create new revisions/requests. No offline synchronization is implemented. Pending uploads remain quarantined until a future scanner/registration process explicitly admits them; a file extension or client MIME alone is not safety evidence.
