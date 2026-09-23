"""Deterministically reconstruct Lubukusu dictionary entries from OCR lines.

The PDF's embedded font has no usable Unicode cmap, so text is obtained by
rendering each page and applying OCR.  OCR results are ordered by page and
column before entry parsing.  The original spelling is retained verbatim;
search normalization is exposed separately.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from dataclasses import asdict, dataclass
from pathlib import Path


PARSER_VERSION = "lubukusu-pdf-ocr-v1"
POS = ("adj", "adv", "comp", "conj", "dem", "excl", "ideo", "loc", "n", "neg", "np", "num", "poss", "pp", "prep", "pron", "q", "relcl", "s", "v", "vint", "vrefl", "vpass", "vtr", "vp", "wh")
ENTRY_RE = re.compile(r"^(.+?)\s+(" + "|".join(sorted(POS, key=len, reverse=True)) + r")(?:\s+(.+))?$", re.IGNORECASE)


@dataclass(frozen=True)
class OCRLine:
    page: int
    column: int
    y: float
    x: float
    text: str
    confidence: float


@dataclass(frozen=True)
class ParsedEntry:
    source_page: int
    sequence: int
    original_form: str
    original_gloss: str
    original_pos: str
    raw_annotations: str
    uncertainty_marker: bool
    raw_dialect_label: str
    raw_text: str
    entry_checksum: str


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def secondary_search_form(value: str) -> str:
    """Accent-insensitive search key; never used as stored source spelling."""
    decomposed = unicodedata.normalize("NFD", value)
    unmarked = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(unicodedata.normalize("NFC", unmarked).casefold().split())


def order_ocr_lines(page: int, boxes: list, texts: list[str], scores: list[float], width: float) -> list[OCRLine]:
    lines: list[OCRLine] = []
    midpoint = width / 2
    for box, text, score in zip(boxes, texts, scores):
        cleaned = " ".join(unicodedata.normalize("NFC", text).split())
        if not cleaned or cleaned == str(page):
            continue
        x = min(point[0] for point in box)
        y = min(point[1] for point in box)
        column = 0 if x < midpoint else 1
        lines.append(OCRLine(page, column, round(float(y), 3), round(float(x), 3), cleaned, float(score)))
    return sorted(lines, key=lambda line: (line.column, line.y, line.x, line.text))


def parse_lines(lines: list[OCRLine]) -> list[ParsedEntry]:
    drafts: list[dict] = []
    current: dict | None = None
    for line in sorted(lines, key=lambda item: (item.page, item.column, item.y, item.x, item.text)):
        if line.page < 4:
            continue
        match = ENTRY_RE.match(line.text)
        if match:
            if current:
                drafts.append(current)
            form, pos, gloss = match.groups()
            current = {"page": line.page, "form": form.strip(), "pos": pos.casefold(), "glosses": [gloss.strip()] if gloss else [], "raw": [line.text]}
        elif current:
            current["glosses"].append(line.text)
            current["raw"].append(line.text)
    if current:
        drafts.append(current)

    entries: list[ParsedEntry] = []
    for sequence, draft in enumerate(drafts, 1):
        gloss = " ".join(draft["glosses"])
        raw = "\n".join(draft["raw"])
        annotations = " (?)" if "(?)" in raw else ""
        checksum_input = json.dumps(
            [draft["page"], sequence, draft["form"], gloss, draft["pos"], raw],
            ensure_ascii=False,
            separators=(",", ":"),
        )
        entries.append(ParsedEntry(
            source_page=draft["page"], sequence=sequence,
            original_form=draft["form"], original_gloss=gloss,
            original_pos=draft["pos"], raw_annotations=annotations.strip(),
            uncertainty_marker="(?)" in raw, raw_dialect_label="Lubukusu",
            raw_text=raw,
            entry_checksum=hashlib.sha256(checksum_input.encode("utf-8")).hexdigest(),
        ))
    return entries


def ocr_pdf(path: Path, dpi_scale: float = 3.0) -> list[OCRLine]:
    import pymupdf
    from rapidocr import RapidOCR

    engine = RapidOCR()
    doc = pymupdf.open(path)
    all_lines: list[OCRLine] = []
    for index, page in enumerate(doc):
        pix = page.get_pixmap(matrix=pymupdf.Matrix(dpi_scale, dpi_scale), alpha=False)
        result = engine(pix.tobytes("png"))
        if result and result.txts:
            all_lines.extend(order_ocr_lines(index + 1, list(result.boxes), list(result.txts), list(result.scores), pix.width))
        print(f"OCR page {index + 1}/{len(doc)}", flush=True)
    return all_lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ocr-cache", type=Path)
    args = parser.parse_args()
    if args.ocr_cache and args.ocr_cache.exists():
        lines = [OCRLine(**row) for row in json.loads(args.ocr_cache.read_text(encoding="utf-8"))]
    else:
        lines = ocr_pdf(args.pdf)
        if args.ocr_cache:
            args.ocr_cache.parent.mkdir(parents=True, exist_ok=True)
            args.ocr_cache.write_text(json.dumps([asdict(line) for line in lines], ensure_ascii=False), encoding="utf-8")
    entries = parse_lines(lines)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps([asdict(entry) for entry in entries], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"parser_version": PARSER_VERSION, "pdf_sha256": sha256_file(args.pdf), "entries": len(entries)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
