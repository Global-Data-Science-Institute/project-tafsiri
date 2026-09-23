from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from scripts.source_registry.register_sources import RegistryError, RestClient

WRITABLE_TABLES = {"dialects", "dialect_aliases"}


class GuardedClient:
    def __init__(self, inner: RestClient): self.inner = inner
    def select(self, table: str, filters: dict[str, Any]): return self.inner.select(table, filters)
    def insert(self, table: str, row: dict[str, Any]):
        if table not in WRITABLE_TABLES: raise RegistryError(f"write guard rejected table: {table}")
        return self.inner._request("POST", table, body=row, extra={"Prefer":"return=representation"})[0]


def load_manifest(path: Path) -> dict[str, Any]: return json.loads(path.read_text(encoding="utf-8"))


def validate_manifest(manifest: dict[str, Any]) -> dict[str, int]:
    errors=[]; canon=manifest.get("canonical_dialects") or []; aliases=manifest.get("aliases") or []
    if not manifest.get("registry_version"): errors.append("registry_version is required")
    if len(canon)!=len(set(canon)) or any(not isinstance(x,str) or not x.strip() for x in canon): errors.append("canonical names must be unique and non-blank")
    names=[x.get("name") for x in aliases]
    if len(names)!=len(set(names)) or any(not x for x in names): errors.append("alias names must be unique and non-blank")
    targets={x.get("canonical_target") for x in aliases}
    if not targets.issubset(set(canon)): errors.append(f"alias targets missing from canonical set: {sorted(targets-set(canon))}")
    overlap=set(names)&set(canon)
    if overlap: errors.append(f"aliases duplicate canonical names: {sorted(overlap)}")
    parents=manifest.get("environment_policy") or {}
    if set(parents.values())!={"Luhya","Staging Luhya"}: errors.append("production and staging parent language policies are required")
    if errors: raise RegistryError("\n".join(errors))
    return {"canonical_dialects":len(canon),"aliases":len(aliases),"environments":len(parents)}


def plan(manifest: dict[str, Any], client: Any, project_ref: str) -> tuple[dict[str,int], dict[str,Any]]:
    validate_manifest(manifest)
    parent_name=(manifest.get("environment_policy") or {}).get(project_ref)
    if not parent_name: raise RegistryError(f"project ref is not approved by manifest: {project_ref}")
    parents=client.select("languages",{"name":parent_name})
    if len(parents)!=1: raise RegistryError(f"expected exactly one parent language named {parent_name}; found {len(parents)}")
    parent=parents[0]; existing_dialects={x["name"]:x for x in client.select("dialects",{})}
    existing_aliases={x["name"]:x for x in client.select("dialect_aliases",{})}
    counts=Counter(dialects_create=0,dialects_reuse=0,aliases_create=0,aliases_reuse=0,conflicts=0)
    canonical={}
    for name in manifest["canonical_dialects"]:
        row=existing_dialects.get(name)
        if row:
            if row.get("language_id")!=parent["id"]: raise RegistryError(f"CONFLICT canonical dialect {name} belongs to another language")
            counts["dialects_reuse"]+=1; canonical[name]=row
        else:
            counts["dialects_create"]+=1; canonical[name]={"id":f"planned:{name}","name":name,"language_id":parent["id"]}
    for item in manifest["aliases"]:
        row=existing_aliases.get(item["name"]); target=canonical[item["canonical_target"]]
        if row:
            if row.get("dialect_id")!=target["id"]: raise RegistryError(f"CONFLICT alias {item['name']} targets a different dialect")
            counts["aliases_reuse"]+=1
        else: counts["aliases_create"]+=1
    return dict(counts),{"parent":parent,"canonical":canonical,"existing_aliases":existing_aliases}


def register(manifest: dict[str, Any], client: Any, project_ref: str, execute: bool) -> dict[str,int]:
    counts,state=plan(manifest,client,project_ref)
    if not execute: return counts
    parent=state["parent"]; canonical=state["canonical"]
    for name in manifest["canonical_dialects"]:
        if str(canonical[name]["id"]).startswith("planned:"):
            canonical[name]=client.insert("dialects",{"name":name,"language_id":parent["id"]})
    for item in manifest["aliases"]:
        if item["name"] not in state["existing_aliases"]:
            client.insert("dialect_aliases",{"name":item["name"],"dialect_id":canonical[item["canonical_target"]]["id"]})
    return counts


def main(argv: list[str]|None=None)->int:
    p=argparse.ArgumentParser(); p.add_argument("--manifest",type=Path,default=Path("config/dialects/canonical_dialect_registry_001.json"))
    modes=p.add_mutually_exclusive_group(required=True); modes.add_argument("--validate",action="store_true"); modes.add_argument("--dry-run",action="store_true"); modes.add_argument("--execute",action="store_true")
    p.add_argument("--project-ref"); p.add_argument("--confirm-project-ref"); a=p.parse_args(argv)
    manifest=load_manifest(a.manifest); counts=validate_manifest(manifest)
    if a.validate: print(json.dumps({"status":"VALID","manifest_counts":counts},sort_keys=True)); return 0
    if not a.project_ref: p.error("--project-ref is required")
    if a.execute and a.confirm_project_ref!=a.project_ref: p.error("--execute requires matching --confirm-project-ref")
    url=os.environ.get("SUPABASE_URL"); key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SECRET_KEY")
    if not url or not key or a.project_ref not in url: raise RegistryError("matching SUPABASE_URL and service role/secret key are required")
    result=register(manifest,GuardedClient(RestClient(url,key)),a.project_ref,a.execute)
    print(json.dumps({"status":"EXECUTED" if a.execute else "DRY_RUN","project_ref":a.project_ref,"changes":result},sort_keys=True)); return 0

if __name__=="__main__":
    try: raise SystemExit(main())
    except RegistryError as exc: print(f"ERROR: {exc}",file=sys.stderr); raise SystemExit(1)
