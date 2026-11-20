"""Internal transport-neutral client for Migration 013's scoped interfaces.

The injected transport is an authenticated DB connection owned by the host
application. This module neither provisions credentials nor provides an HTTP API.
"""
from .language_profile import scope, validate_profile


class RegistryClient:
    def __init__(self, query_one):
        self.query_one = query_one

    def lookup(self, identity):
        scope(identity)
        return self.query_one('SELECT language_registry.lookup(%s,%s::uuid)',
                              (identity['kind'], identity['id']))

    def orthographies(self, identity):
        return self.lookup(identity)['orthographies']

    def capabilities(self, identity):
        info = self.lookup(identity)
        return {'registered': info['registered'], 'research_enabled': info['research_enabled'],
                **{key: key in info['capabilities'] for key in (
                    'DATASET_ELIGIBLE', 'MODEL_EVALUATION_ELIGIBLE', 'MODEL_AVAILABLE', 'COMMERCIALLY_AVAILABLE')}}

    def resolve(self, document):
        profile = validate_profile(document)
        p = profile.values
        info = self.lookup(p['source'])
        if not info['research_enabled']:
            raise ValueError('research not enabled')
        # Target access is independent, never inherited from the source.
        if p['target'] is not None:
            self.lookup(p['target'])
        orthographies = [o for o in info['orthographies'] if o['id'] == p['orthography']['id']
                        and o['version'] == p['orthography']['version'] and o['normalization'] == p['normalization']]
        if len(orthographies) != 1:
            raise ValueError('approved orthography mismatch')
        resolved = self.query_one('SELECT language_registry.resolve_configuration(%s,%s::uuid,%s,%s)',
                                  (p['source']['kind'], p['source']['id'], p['key'], p['version']))
        if resolved['sha256'] != profile.config_hash or resolved['orthography_id'] != p['orthography']['id']:
            raise ValueError('approved configuration digest mismatch')
        return profile
