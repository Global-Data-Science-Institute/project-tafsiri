# Tafsiri AI Research Assistant 001

The assistant is a provider-neutral proposal layer inside Data Studio. Its interface accepts an authorized immutable contribution snapshot plus workflow and returns structured suggestions; it has no tools for canonical writes, language registration, reviewer assignment or training. It never certifies language correctness.

The first implemented adapter is deterministic and offline for synthetic testing. External providers, including a future OpenAI Responses adapter, are explicitly unsupported scaffolding until separately reviewed. No API key is needed and no content is transmitted externally. Unsupported providers fail closed. This deliberate limit allows testing all governance without granting private-data processing permission.

| Workflow | Offline MVP behavior / future boundary |
|---|---|
| Document assistance | Proposes metadata from contributor-supplied text and evidence references; raw document OCR/parsing is deferred and quarantine files are never executed |
| Contributor assistance | Identifies missing context/source/counterpart scope and asks targeted questions |
| Linguistic candidates | Returns uncertainty and requests qualified human input; no unsupported interpretation, morphology or translation |
| Quality assistance | Flags identical own/project-visible text, missing metadata and unresolved scope; possible transcription/contradiction judgments require evidence and remain proposals |
| Task preparation | Proposes an annotation task descriptor referencing the exact contribution revision; handoff remains blocked until authorized integration |

All outputs carry MACHINE_GENERATED and UNVERIFIED, adapter/model identity, prompt/configuration version, evidence ID/revision, elapsed processing time and workflow. The database recomputes/stores offline results through a controlled operation rather than allowing clients to label arbitrary supplied output as trusted adapter output. Suggestions are separate from submitted originals and cannot confer rights.

Future providers must implement the same bounded contract, structured-output validation, timeout, size/token budget, daily/project limits, idempotent request records, cancellation, secret custody and redacted error handling. Admission must require current project AND contribution external-processing consent, permitted purpose, an approved provider/region/retention policy and a human-authorized evidence set. User text is untrusted data, never instructions to change policy or execute tools. API keys stay server-side; no training/retention setting is inferred from a provider name. Consent revoked during processing blocks publication and invokes the documented retention/deletion procedure.

No reliable language support means uncertainty or a request for human input. A model must not invent native vocabulary, translate without supporting evidence, or treat its own outputs as human verification. Synthetic adapter success is not evidence of model capability. Real external integration requires current provider documentation and a separately reviewed implementation; it is not provisioned here.
