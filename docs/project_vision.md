# Project Tafsiri vision

Project Tafsiri builds trustworthy multilingual African-language research and AI infrastructure. Luhya remains the first reference implementation and primary research focus, including English-Luhya and Swahili-Luhya work, with each Luhya variety represented as a first-class linguistic identity.

## Principles

- Native-speaker and expert review determines linguistic validity.
- Human-verified evidence outranks machine-generated material.
- Dialects remain distinct; the project does not manufacture a generalized vocabulary by mixing them.
- Every lexical assertion should retain enough source and review provenance to be audited.
- When no verified or established borrowed term exists, preserve the source term and explain it naturally. Do not guess.
- Sensitive and community-contributed material must retain consent, attribution, and access controls.

## Current focus

The current architecture supports a canonical lexical core, source provenance, candidate generation, frozen evaluation evidence, and independent review through the Reviewer Portal. Claims about translation quality, trained models, language coverage, or public availability require supporting evidence and are not implied by the repository structure.

## Measures of progress

Progress is measured through traceable sources, independent human review, dialect coverage, reproducible evaluation, data safety, and reliable operation of the review workflow.

## Multilingual design direction

The [Multilingual Architecture Amendment 001](research/multilingual-architecture-amendment-001.md) extends the existing research pipeline and Reviewer Portal through language-aware scope and governance. It preserves `Lexeme → Form → Sense → Concept`, distinct varieties, provenance and separate human approval gates. Registry membership does not establish translation support.

The future [Model Lab](research/tafsiri-model-lab-architecture-001.md) begins with approved Luwanga resources. [Tafsiri Cloud](architecture/tafsiri-cloud-commercial-architecture-001.md) is a separate future commercial boundary consuming cleared, approved model artifacts. Neither production training nor commercial serving is introduced by these specifications. See the [language onboarding process](language_inclusion_framework.md) and [compatibility report](research/multilingual-compatibility-validation-001.md).
