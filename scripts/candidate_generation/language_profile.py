"""Versioned opt-in profiles for the existing candidate-generation engine.

An allowlist is an input restriction, never a permission grant. Snapshot custody
and authorization are responsibilities of the trusted research exporter.
"""
from __future__ import annotations

import hashlib
import json
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from uuid import UUID


def canonical_digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":"), allow_nan=False).encode("utf-8")).hexdigest()


def exact_keys(value, keys, label):
    if not isinstance(value, dict) or set(value) != set(keys):
        raise ValueError(f"{label}: required keys are {sorted(keys)}; unknown keys are not supported")


def uuid_value(value):
    if not isinstance(value, str) or str(UUID(value)) != value:
        raise ValueError("canonical UUID required")
    return value


def scope(value):
    exact_keys(value, ('kind', 'id'), 'scope')
    if value['kind'] not in ('language', 'variety'):
        raise ValueError('scope kind must be language or variety')
    uuid_value(value['id'])
    return value


def nonblank(value, label):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f'{label} must be nonblank text')


@dataclass(frozen=True)
class LanguageProfile:
    # JSON is kept as immutable bytes; callers receive fresh objects.
    document: str
    config_hash: str

    @property
    def values(self):
        return json.loads(self.document)

    def normalize(self, value):
        mode = self.values['normalization']
        return unicodedata.normalize('NFC', value) if mode == 'NFC' else value

    def tokens(self, value):
        return value.split() if self.values['tokenization'] == 'WHITESPACE_V1' else []


def validate_profile(document):
    exact_keys(document, ('contract_version', 'key', 'version', 'source', 'target', 'adapter',
                         'orthography', 'normalization', 'tokenization', 'morphology', 'features',
                         'source_versions', 'artifacts', 'rights_policy_reference',
                         'review_protocol', 'evaluation'), 'language profile')
    if type(document['contract_version']) is not int or document['contract_version'] != 1:
        raise ValueError('unsupported profile contract')
    if type(document['version']) is not int or document['version'] < 1:
        raise ValueError('positive profile version required')
    for key in ('key', 'rights_policy_reference', 'review_protocol'):
        nonblank(document[key], key)
    scope(document['source'])
    if document['target'] is not None:
        scope(document['target'])
    exact_keys(document['orthography'], ('id', 'version'), 'orthography')
    uuid_value(document['orthography']['id'])
    nonblank(document['orthography']['version'], 'orthography version')
    supported = {'adapter': ('SOURCE_ENTRY_SNAPSHOT_V1',), 'normalization': ('PRESERVE', 'NFC'),
                 'tokenization': ('NONE', 'WHITESPACE_V1'), 'morphology': ('NONE',),
                 'features': ('CONSERVATIVE_V1',)}
    for key, choices in supported.items():
        if document[key] not in choices:
            raise ValueError(f'unsupported {key}: {document[key]!r}')
    for key in ('source_versions', 'artifacts'):
        items = document[key]
        if not isinstance(items, list) or not items:
            raise ValueError(f'{key}: explicit nonempty allowlist required')
        for item in items:
            uuid_value(item)
        if len(set(items)) != len(items):
            raise ValueError(f'{key}: duplicate identifiers')
    exact_keys(document['evaluation'], ('protocol', 'split'), 'evaluation')
    nonblank(document['evaluation']['protocol'], 'evaluation protocol')
    if document['evaluation']['split'] not in ('SYNTHETIC', 'RESEARCH'):
        raise ValueError('unsupported evaluation split')
    return LanguageProfile(json.dumps(document, ensure_ascii=False, allow_nan=False), canonical_digest(document))


def load_profile(path: Path):
    return validate_profile(read_document(path))


def read_document(path: Path):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'duplicate JSON key: {key}')
            result[key] = value
        return result

    def reject_constant(value):
        raise ValueError(f'non-JSON numeric constant: {value}')

    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object,
                      parse_constant=reject_constant)


@dataclass(frozen=True)
class ScopedSourceEntry:
    """Existing source-entry snapshot; compatibility properties are internal only."""
    record_json: str

    @property
    def record(self):
        return json.loads(self.record_json)

    @property
    def id(self):
        return self.record['source_entry_id']

    @property
    def word(self):
        return self.record['original_form']

    @property
    def english_definition(self):
        # CorpusIndex's historical attribute name; no English feature is used.
        return self.record['original_gloss'] or ''

    @property
    def dialect_id(self):
        s = self.record['headword_scope']
        return f"{s['kind']}:{s['id']}"

    word_normalized = None
    part_of_speech = None


def load_snapshot(path: Path, profile: LanguageProfile):
    payload = read_document(path)
    return validate_snapshot(payload, profile)


def validate_snapshot(payload, profile: LanguageProfile):
    exact_keys(payload, ('contract_version', 'records'), 'snapshot')
    if type(payload['contract_version']) is not int or payload['contract_version'] != 1 or not isinstance(payload['records'], list):
        raise ValueError('unsupported snapshot contract')
    p = profile.values
    result, seen = [], set()
    for row in payload['records']:
        exact_keys(row, ('source_id', 'source_version_id', 'artifact_id', 'artifact_sha256',
                         'import_batch_id', 'source_entry_id', 'source_locator', 'original_form',
                         'original_gloss', 'headword_scope', 'gloss_scope', 'scope_assertion_ids',
                         'rights_policy_reference', 'synthetic'), 'source entry')
        for key in ('source_id', 'source_version_id', 'artifact_id', 'import_batch_id', 'source_entry_id'):
            uuid_value(row[key])
        if row['source_entry_id'] in seen:
            raise ValueError('duplicate source entry')
        seen.add(row['source_entry_id'])
        if row['source_version_id'] not in p['source_versions'] or row['artifact_id'] not in p['artifacts']:
            raise ValueError('source or artifact not allowlisted')
        if scope(row['headword_scope']) != p['source']:
            raise ValueError('headword scope mismatch; no inferred scope expansion')
        if row['gloss_scope'] is not None:
            scope(row['gloss_scope'])
        if row['gloss_scope'] != p['target']:
            raise ValueError('gloss scope mismatch')
        if row['original_gloss'] is not None and not isinstance(row['original_gloss'], str):
            raise ValueError('gloss must be text or null')
        if row['original_gloss'] and row['gloss_scope'] is None:
            raise ValueError('gloss language is unresolved')
        for key in ('source_locator', 'original_form'):
            nonblank(row[key], key)
        digest = row['artifact_sha256']
        if not isinstance(digest, str) or len(digest) != 64 or any(c not in '0123456789abcdef' for c in digest):
            raise ValueError('SHA-256 artifact digest required')
        if not isinstance(row['scope_assertion_ids'], list) or not row['scope_assertion_ids']:
            raise ValueError('reviewed scope assertion references required')
        for ident in row['scope_assertion_ids']:
            uuid_value(ident)
        if row['rights_policy_reference'] != p['rights_policy_reference']:
            raise ValueError('rights policy reference mismatch')
        if type(row['synthetic']) is not bool or (p['evaluation']['split'] == 'SYNTHETIC' and not row['synthetic']):
            raise ValueError('synthetic evaluation requires explicitly synthetic records')
        result.append(ScopedSourceEntry(json.dumps(row, ensure_ascii=False)))
    return result


@dataclass(frozen=True)
class ScopedCandidate:
    source_entry_id: str
    proposed_gloss: str | None
    evidence: dict
    concept_id: None = None
    proposed_concept_key: None = None
    mapping_source: str = 'conservative_profile'
    confidence: float = 0.0
    mapping_status: str = 'needs_review'

    def to_dict(self):
        from dataclasses import asdict
        return asdict(self)


def build_scoped_candidate(entry, signals, profile):
    p = profile.values
    flags = ['REQUIRES_HUMAN_REVIEW']
    if signals.distinct_definition_count > 1:
        flags.append('REPEATED_FORM_DIFFERENT_GLOSSES')
    return ScopedCandidate(entry.id, entry.record['original_gloss'], {
        'schema_version': 'pipeline-scoped-evidence-v1', 'config_hash': profile.config_hash,
        'profile_key': p['key'], 'profile_version': p['version'], 'source': entry.record,
        'analysis': {'normalized_form': profile.normalize(entry.word),
                     'tokens': profile.tokens(entry.word), 'normalization': p['normalization'],
                     'morphology': 'NONE', 'semantic_equivalence_asserted': False},
        'classification': {'bucket': 'REVIEW', 'ambiguity_indicators': flags},
        'existing_concept_suggestions': [], 'rights_granted': False,
        'review_protocol': p['review_protocol'], 'evaluation': p['evaluation'],
    })
