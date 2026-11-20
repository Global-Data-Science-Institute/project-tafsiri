"""Synthetic only. No vocabulary, translation quality or real approval claims."""
import copy
import json
from pathlib import Path
from uuid import UUID

import pytest

from scripts.candidate_generation.cli import generate, main
from scripts.candidate_generation.language_profile import validate_profile, validate_snapshot, load_profile
from scripts.candidate_generation.registry import RegistryClient


def uid(n):
    return str(UUID(int=130000+n))


def profile_document(kind='language', ident=1):
    return {
        'contract_version': 1, 'key': 'SYNTHETIC_PROFILE', 'version': 1,
        'source': {'kind': kind, 'id': uid(ident)}, 'target': {'kind': 'language', 'id': uid(2)},
        'adapter': 'SOURCE_ENTRY_SNAPSHOT_V1', 'orthography': {'id': uid(3), 'version': 'SYNTHETIC-v1'},
        'normalization': 'PRESERVE', 'tokenization': 'NONE', 'morphology': 'NONE',
        'features': 'CONSERVATIVE_V1', 'source_versions': [uid(4)], 'artifacts': [uid(5)],
        'rights_policy_reference': 'SYNTHETIC-NOT-A-PERMISSION',
        'review_protocol': 'SYNTHETIC-REVIEW-v1', 'evaluation': {'protocol': 'SYNTHETIC-EVAL-v1', 'split': 'SYNTHETIC'},
    }


def snapshot_document(profile=None):
    p = profile or profile_document()
    return {'contract_version': 1, 'records': [{
        'source_id': uid(6), 'source_version_id': uid(4), 'artifact_id': uid(5),
        'artifact_sha256': '0'*64, 'import_batch_id': uid(7), 'source_entry_id': uid(8),
        'source_locator': 'SYNTHETIC:row:1', 'original_form': 'SYNTHETIC_FORM',
        'original_gloss': 'SYNTHETIC_MEANING_A', 'headword_scope': p['source'], 'gloss_scope': p['target'],
        'scope_assertion_ids': [uid(9)], 'rights_policy_reference': p['rights_policy_reference'], 'synthetic': True,
    }]}


@pytest.mark.parametrize('field,value', [
    ('contract_version', 2), ('version', True), ('normalization', 'LUWANGA_DEFAULT'),
    ('normalization', 'NFKC'), ('tokenization', 'AUTO'), ('morphology', 'BANTU'),
    ('features', 'ENGLISH_GLOSSES'), ('adapter', 'AUTO_LANGUAGE'), ('source_versions', []),
    ('artifacts', ['not-a-uuid']), ('rights_policy_reference', ''), ('source', {'kind':'language','id':None}),
])
def test_unsupported_profiles_fail_closed(field, value):
    p = profile_document(); p[field] = value
    with pytest.raises(ValueError):
        validate_profile(p)


def test_unknown_settings_and_immutable_profile():
    p = profile_document(); p['guess_language'] = True
    with pytest.raises(ValueError): validate_profile(p)
    del p['guess_language']
    cfg = validate_profile(p)
    p['normalization'] = 'NFC'
    cfg.values['normalization'] = 'NFC'
    assert cfg.values['normalization'] == 'PRESERVE'


@pytest.mark.parametrize('field,value', [
    ('headword_scope', {'kind': 'variety', 'id': uid(1)}),
    ('gloss_scope', {'kind': 'language', 'id': uid(99)}),
    ('source_version_id', uid(99)), ('artifact_id', uid(99)),
    ('rights_policy_reference', 'OTHER'), ('artifact_sha256', 'bad'),
    ('scope_assertion_ids', []), ('synthetic', False), ('source_entry_id', None),
])
def test_snapshot_scope_provenance_rejections(field, value):
    s = snapshot_document(); s['records'][0][field] = value
    with pytest.raises(ValueError): validate_snapshot(s, validate_profile(profile_document()))


@pytest.mark.parametrize('kind,ident', [('language',1),('language',20),('variety',21),('variety',22)])
def test_same_engine_unrelated_language_and_varieties(kind, ident):
    p = profile_document(kind, ident); cfg = validate_profile(p)
    s = snapshot_document(p)
    second = copy.deepcopy(s['records'][0]); second['source_entry_id'] = uid(10)
    second['original_gloss'] = 'SYNTHETIC_MEANING_B'
    s['records'].append(second)
    candidates, index = generate(validate_snapshot(s, cfg), [], cfg)
    assert index.repeated_form_group_count == 1
    assert len(candidates) == 2
    for candidate in candidates:
        assert candidate.mapping_status == 'needs_review'
        assert candidate.concept_id is None and candidate.confidence == 0
        assert candidate.evidence['source']['headword_scope'] == p['source']
        assert not candidate.evidence['rights_granted']
        assert not candidate.evidence['analysis']['semantic_equivalence_asserted']
        assert 'REPEATED_FORM_DIFFERENT_GLOSSES' in candidate.evidence['classification']['ambiguity_indicators']


def test_profile_revalidated_at_generation_and_normalization_preserves_original():
    p = profile_document(); cfg = validate_profile(p)
    records = validate_snapshot(snapshot_document(), cfg)
    p['source']['id'] = uid(99)
    with pytest.raises(ValueError, match='scope mismatch'): generate(records, [], validate_profile(p))
    p = profile_document(); p['normalization'] = 'NFC'; p['tokenization'] = 'WHITESPACE_V1'
    s = snapshot_document(p); s['records'][0]['original_form'] = 'SYNTHETIC e\u0301 FORM'
    cfg = validate_profile(p)
    candidates, _ = generate(validate_snapshot(s, cfg), [], cfg)
    assert candidates[0].evidence['analysis']['normalized_form'] == 'SYNTHETIC é FORM'
    assert candidates[0].evidence['source']['original_form'] == 'SYNTHETIC e\u0301 FORM'
    assert len(candidates[0].evidence['analysis']['tokens']) == 3


def test_cli_uses_existing_exports_and_never_network(tmp_path, monkeypatch):
    def forbidden(*args, **kwargs): raise AssertionError('network called')
    monkeypatch.setattr('urllib.request.urlopen', forbidden)
    p = tmp_path/'profile.json'; p.write_text(json.dumps(profile_document()))
    s = tmp_path/'snapshot.json'; s.write_text(json.dumps(snapshot_document()))
    out = tmp_path/'out'
    assert main(['--dry-run','--language-profile',str(p),'--input-snapshot',str(s),'--output-dir',str(out)]) == 0
    row = json.loads((out/'pipeline_001.jsonl').read_text())
    assert row['source_entry_id'] == uid(8) and 'dictionary_entry_id' not in row
    assert 'proposed_definition_en' not in row
    assert row['proposed_gloss'] == 'SYNTHETIC_MEANING_A'
    with pytest.raises(FileExistsError):
        main(['--dry-run','--language-profile',str(p),'--input-snapshot',str(s),'--output-dir',str(out)])
    with pytest.raises(SystemExit, match='fresh output'):
        main(['--dry-run','--language-profile',str(p),'--input-snapshot',str(s)])
    with pytest.raises(SystemExit, match='no Luwanga fallback'):
        main(['--dry-run','--input-snapshot',str(s)])
    d = profile_document(); d['evaluation']['split']='RESEARCH'; p.write_text(json.dumps(d))
    with pytest.raises(SystemExit, match='private adapter'):
        main(['--dry-run','--language-profile',str(p),'--input-snapshot',str(s),'--output-dir',str(out)])


def test_internal_registry_resolution_uses_parameters_and_exact_approvals():
    p = profile_document(); cfg = validate_profile(p)
    calls = []
    def query(sql, params):
        calls.append((sql,params))
        if 'resolve_configuration' in sql:
            return {'sha256': cfg.config_hash, 'orthography_id': uid(3)}
        return {'registered':True,'research_enabled':True, 'capabilities':[],
                'orthographies':[{'id':uid(3),'version':'SYNTHETIC-v1','normalization':'PRESERVE'}]}
    client = RegistryClient(query)
    assert client.resolve(p).config_hash == cfg.config_hash
    assert calls[1][1] == ('language',uid(2))  # independent target access
    assert client.capabilities(p['source'])['MODEL_AVAILABLE'] is False
    assert all('%s' in sql and uid(1) not in sql for sql,_ in calls)
    p['key'] = "SYNTHETIC'; SELECT secret; --"
    with pytest.raises(ValueError, match='digest mismatch'): client.resolve(p)


def test_registry_denial_is_not_fallback():
    def denied(*args): raise PermissionError('scope denied')
    with pytest.raises(PermissionError): RegistryClient(denied).resolve(profile_document())


@pytest.mark.parametrize('content', ['{"version":1,"version":2}', '{"version":NaN}'])
def test_ambiguous_json_is_rejected(tmp_path, content):
    p = tmp_path/'profile.json'; p.write_text(content)
    with pytest.raises(ValueError): load_profile(p)


def test_checked_in_synthetic_profiles_use_the_existing_engine():
    from scripts.candidate_generation.language_profile import load_snapshot
    root = Path(__file__).resolve().parents[1]/'fixtures/multilingual'
    profiles = sorted(root.glob('*_profile.json'))
    assert len(profiles) == 4
    for path in profiles:
        p = load_profile(path)
        candidates, _ = generate(load_snapshot(path.with_name(path.name.replace('_profile','_snapshot')), p), [], p)
        assert len(candidates) == 1 and candidates[0].evidence['source']['synthetic'] is True
