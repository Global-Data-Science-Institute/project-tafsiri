from __future__ import annotations

import argparse
import csv
import json
import shutil
import threading
import webbrowser
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

BASE = Path(__file__).resolve().parent
SOURCE = BASE / "human_review_001.jsonl"
ANNOTATIONS = BASE / "human_review_001_annotations.jsonl"
STATE = BASE / "human_review_001_state.json"
STATIC = BASE / "wizard"
DECISIONS = {"ACCEPT_SIMPLE", "ACCEPT_VARIANT", "SPLIT_SENSES", "NEEDS_EXPERT"}
AGREEMENTS = {"YES", "NO", "UNSURE"}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_records() -> list[dict]:
    rows = [json.loads(line) for line in SOURCE.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(rows) != 150 or len({r["dictionary_entry_id"] for r in rows}) != 150:
        raise RuntimeError("Frozen review sample must contain exactly 150 unique records")
    return rows


def read_annotations() -> dict[str, dict]:
    if not ANNOTATIONS.exists(): return {}
    rows = [json.loads(line) for line in ANNOTATIONS.read_text(encoding="utf-8").splitlines() if line.strip()]
    return {r["dictionary_entry_id"]: r for r in rows}


def read_state() -> dict:
    default = {"reviewer": {}, "last_index": 0, "started_at": None, "updated_at": None}
    if not STATE.exists(): return default
    return default | json.loads(STATE.read_text(encoding="utf-8"))


def atomic_text(path: Path, text: str) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    temporary.replace(path)


def save_annotations(items: dict[str, dict]) -> None:
    text = "".join(json.dumps(items[key], ensure_ascii=False, sort_keys=True) + "\n" for key in sorted(items))
    atomic_text(ANNOTATIONS, text)


def save_state(state: dict) -> None:
    atomic_text(STATE, json.dumps(state, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def completed(annotation: dict | None) -> bool:
    return bool(annotation and annotation.get("reviewer_decision") in DECISIONS
                and annotation.get("pipeline_bucket_correct") in AGREEMENTS
                and annotation.get("pipeline_ambiguity_correct") in AGREEMENTS)


def validate_annotation(payload: dict, valid_ids: set[str]) -> dict:
    identifier = payload.get("dictionary_entry_id")
    if identifier not in valid_ids: raise ValueError("Unknown dictionary record")
    decision = payload.get("reviewer_decision", "")
    bucket = payload.get("pipeline_bucket_correct", "")
    ambiguity = payload.get("pipeline_ambiguity_correct", "")
    if decision and decision not in DECISIONS: raise ValueError("Invalid reviewer decision")
    if bucket and bucket not in AGREEMENTS: raise ValueError("Invalid bucket assessment")
    if ambiguity and ambiguity not in AGREEMENTS: raise ValueError("Invalid ambiguity assessment")
    return {
        "dictionary_entry_id": identifier,
        "reviewer_decision": decision,
        "reviewer_concept_label": str(payload.get("reviewer_concept_label", "")),
        "reviewer_definition": str(payload.get("reviewer_definition", "")),
        "reviewer_notes": str(payload.get("reviewer_notes", "")),
        "pipeline_bucket_correct": bucket,
        "pipeline_ambiguity_correct": ambiguity,
        "annotation_created_at": payload.get("annotation_created_at") or now(),
        "annotation_updated_at": now(),
    }


def versioned_backup(path: Path) -> Path | None:
    if not path.exists(): return None
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    backup = path.with_name(f"{path.stem}_backup_{stamp}{path.suffix}")
    shutil.copy2(path, backup)
    return backup


def summary(records: list[dict], annotations: dict[str, dict]) -> dict:
    decision_counts = {name: 0 for name in sorted(DECISIONS)}
    bucket_counts = {name: 0 for name in sorted(AGREEMENTS)}
    ambiguity_counts = {name: 0 for name in sorted(AGREEMENTS)}
    for item in annotations.values():
        if item.get("reviewer_decision") in decision_counts: decision_counts[item["reviewer_decision"]] += 1
        if item.get("pipeline_bucket_correct") in bucket_counts: bucket_counts[item["pipeline_bucket_correct"]] += 1
        if item.get("pipeline_ambiguity_correct") in ambiguity_counts: ambiguity_counts[item["pipeline_ambiguity_correct"]] += 1
    done = sum(completed(annotations.get(r["dictionary_entry_id"])) for r in records)
    return {"total": 150, "completed": done, "incomplete": 150 - done,
            "decision_counts": decision_counts, "bucket_agreement_counts": bucket_counts,
            "ambiguity_agreement_counts": ambiguity_counts}


def export_completed(records: list[dict], annotations: dict[str, dict], state: dict) -> dict:
    missing = [index + 1 for index, record in enumerate(records) if not completed(annotations.get(record["dictionary_entry_id"]))]
    if missing: raise ValueError(f"{len(missing)} records are incomplete")
    json_path = BASE / "human_review_001_completed.jsonl"
    csv_path = BASE / "human_review_001_completed.csv"
    report_path = BASE / "human_review_001_review_summary.json"
    backups = [str(x) for x in (versioned_backup(json_path), versioned_backup(csv_path), versioned_backup(report_path)) if x]
    exported = []
    for record in records:
        identifier = record["dictionary_entry_id"]
        exported.append(record | {"reviewer_annotation": annotations[identifier], "reviewer_metadata": state.get("reviewer", {})})
    atomic_text(json_path, "".join(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n" for row in exported))
    flat = []
    for row in exported:
        annotation = row["reviewer_annotation"]
        flat.append({"dictionary_entry_id": row["dictionary_entry_id"], "word": row["word"],
                     "english_definition": row["english_definition"], "bucket": row["bucket"],
                     "mapping_status": row["mapping_status"], **annotation,
                     "reviewer_metadata": json.dumps(row["reviewer_metadata"], ensure_ascii=False)})
    with csv_path.with_suffix(".csv.tmp").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(flat[0])); writer.writeheader(); writer.writerows(flat)
    csv_path.with_suffix(".csv.tmp").replace(csv_path)
    report = summary(records, annotations) | {"reviewer_metadata": state.get("reviewer", {}),
               "review_started_at": state.get("started_at"), "exported_at": now()}
    atomic_text(report_path, json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    return {"files": [str(json_path), str(csv_path), str(report_path)], "backups": backups}


class AppHandler(BaseHTTPRequestHandler):
    records = load_records()
    valid_ids = {r["dictionary_entry_id"] for r in records}

    def log_message(self, *_): pass
    def send_json(self, payload, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body))); self.send_header("Cache-Control", "no-store")
        self.end_headers(); self.wfile.write(body)
    def read_json(self):
        return json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode())

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/bootstrap":
            annotations = read_annotations(); state = read_state()
            return self.send_json({"records": self.records, "annotations": annotations, "state": state,
                                   "summary": summary(self.records, annotations)})
        if path == "/": path = "/index.html"
        target = (STATIC / path.lstrip("/")).resolve()
        if STATIC.resolve() not in target.parents or not target.is_file(): return self.send_error(404)
        types = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8"}
        body = target.read_bytes(); self.send_response(200); self.send_header("Content-Type", types.get(target.suffix, "application/octet-stream")); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)

    def do_POST(self):
        try:
            path = urlparse(self.path).path; payload = self.read_json()
            if path == "/api/annotation":
                items = read_annotations(); item = validate_annotation(payload, self.valid_ids); items[item["dictionary_entry_id"]] = item; save_annotations(items)
                state = read_state(); state["last_index"] = int(payload.get("last_index", state["last_index"])); state["updated_at"] = now(); state["started_at"] = state["started_at"] or now(); save_state(state)
                return self.send_json({"annotation": item, "summary": summary(self.records, items)})
            if path == "/api/state":
                state = read_state(); state["reviewer"] = payload.get("reviewer", state["reviewer"]); state["last_index"] = int(payload.get("last_index", state["last_index"])); state["updated_at"] = now(); state["started_at"] = state["started_at"] or now(); save_state(state); return self.send_json(state)
            if path == "/api/start-over":
                if payload.get("confirmation") != "START OVER": raise ValueError("Explicit confirmation required")
                backups = [str(x) for x in (versioned_backup(ANNOTATIONS), versioned_backup(STATE)) if x]
                if ANNOTATIONS.exists(): ANNOTATIONS.unlink()
                save_state({"reviewer": {}, "last_index": 0, "started_at": None, "updated_at": now()})
                return self.send_json({"backups": backups})
            if path == "/api/export": return self.send_json(export_completed(self.records, read_annotations(), read_state()))
            return self.send_error(404)
        except ValueError as exc: return self.send_json({"error": str(exc)}, HTTPStatus.BAD_REQUEST)
        except Exception as exc: return self.send_json({"error": f"Local application error: {exc}"}, HTTPStatus.INTERNAL_SERVER_ERROR)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Offline Tafsiri Human Review Wizard")
    parser.add_argument("--port", type=int, default=8765); parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args(argv)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), AppHandler)
    url = f"http://127.0.0.1:{args.port}/"
    print(f"Tafsiri review wizard: {url}")
    print("Press Ctrl+C to stop. All data stays in evaluation/candidate_generation.")
    if not args.no_browser: threading.Timer(.5, lambda: webbrowser.open(url)).start()
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()


if __name__ == "__main__": main()
