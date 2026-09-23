import copy
import json
from pathlib import Path

import pytest

from scripts.dialect_registry.register_dialects import RegistryError, register, validate_manifest

PATH=Path("config/dialects/canonical_dialect_registry_001.json")
STAGING="gfhdwmqefotkljrltfnx"; PRODUCTION="ydkookidvipqrwuilqeu"


def manifest(): return json.loads(PATH.read_text(encoding="utf-8"))


class FakeClient:
    def __init__(self,parent="Staging Luhya",existing=None,aliases=None):
        self.tables={"languages":[{"id":"lang-1","name":parent}],"dialects":copy.deepcopy(existing or []),"dialect_aliases":copy.deepcopy(aliases or [])}
        self.writes=[]
    def select(self,table,filters): return [copy.deepcopy(x) for x in self.tables[table] if all(x.get(k)==v for k,v in filters.items())]
    def insert(self,table,row):
        assert table in {"dialects","dialect_aliases"}
        saved={"id":f"{table}-{len(self.tables[table])+1}",**copy.deepcopy(row)}; self.tables[table].append(saved); self.writes.append(table); return copy.deepcopy(saved)


def test_manifest_uniqueness_target_integrity_and_candidate_resolution():
    assert validate_manifest(manifest())=={"canonical_dialects":18,"aliases":17,"environments":2}
    m=manifest(); aliases={x["name"]:x["canonical_target"] for x in m["aliases"]}; canon=set(m["canonical_dialects"])
    candidates={"Khayo","Lubukusu","Lukisa","Lulogooli","Lumarachi","Lumarama","Lunyala","Lunyore","Lusamia","Lutiriki","Lutsotso","Luwanga","Lwidakho","Lwisukha","Tachoni"}
    assert all(name in canon or name in aliases for name in candidates)


def test_staging_parent_preserves_existing_luwanga_id_and_is_idempotent():
    client=FakeClient(existing=[{"id":"keep-me","name":"Luwanga","language_id":"lang-1","description":"QA fixture"}])
    first=register(manifest(),client,STAGING,True)
    assert first=={"dialects_create":17,"dialects_reuse":1,"aliases_create":17,"aliases_reuse":0,"conflicts":0}
    assert next(x for x in client.tables["dialects"] if x["name"]=="Luwanga")["id"]=="keep-me"
    second=register(manifest(),client,STAGING,False)
    assert second=={"dialects_create":0,"dialects_reuse":18,"aliases_create":0,"aliases_reuse":17,"conflicts":0}


def test_production_parent_resolution_and_only_two_missing():
    m=manifest(); existing=[{"id":f"d-{i}","name":n,"language_id":"lang-1"} for i,n in enumerate(m["canonical_dialects"]) if n not in {"Khayo","Lunyore"}]
    result=register(m,FakeClient("Luhya",existing),PRODUCTION,False)
    assert result["dialects_create"]==2 and result["dialects_reuse"]==16


def test_alias_conflict_stops_before_writes():
    existing=[{"id":"bukusu","name":"Bukusu","language_id":"lang-1"},{"id":"kisa","name":"Kisa","language_id":"lang-1"}]
    client=FakeClient(existing=existing,aliases=[{"id":"a","name":"Lubukusu","dialect_id":"kisa"}])
    with pytest.raises(RegistryError,match="CONFLICT alias"): register(manifest(),client,STAGING,True)
    assert client.writes==[]


def test_wrong_parent_conflict_preserves_existing_id():
    client=FakeClient(existing=[{"id":"do-not-touch","name":"Luwanga","language_id":"different"}])
    with pytest.raises(RegistryError,match="another language"): register(manifest(),client,STAGING,True)
    assert client.writes==[] and client.tables["dialects"][0]["id"]=="do-not-touch"


def test_no_reviewer_source_or_evidence_write_paths():
    client=FakeClient(); register(manifest(),client,STAGING,True)
    assert set(client.writes)=={"dialects","dialect_aliases"}
