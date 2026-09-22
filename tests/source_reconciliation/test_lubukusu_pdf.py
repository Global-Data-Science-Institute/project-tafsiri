from scripts.source_reconciliation.lubukusu_pdf import OCRLine, order_ocr_lines, parse_lines


def test_column_order_and_entry_boundaries_are_deterministic() -> None:
    boxes = [
        [[600, 20], [900, 20], [900, 30], [600, 30]],
        [[10, 30], [400, 30], [400, 40], [10, 40]],
        [[10, 20], [400, 20], [400, 30], [10, 30]],
    ]
    lines = order_ocr_lines(4, boxes, ["right n second", "continued", "khúúkholá vtr do"], [1, 1, 1], 1000)
    assert [line.text for line in lines] == ["khúúkholá vtr do", "continued", "right n second"]
    first = parse_lines(lines)
    second = parse_lines(lines)
    assert first == second
    assert first[0].original_form == "khúúkholá"
    assert first[0].original_gloss == "do continued"
    assert first[1].original_form == "right"


def test_uncertainty_multiword_and_vowel_length_preserved() -> None:
    entries = parse_lines([
        OCRLine(51, 0, 10, 10, "khúúkhola buusya (?) vp renew", 0.99),
        OCRLine(51, 0, 20, 10, "with multiple glosses, restore", 0.99),
    ])
    assert entries[0].original_form == "khúúkhola buusya (?)"
    assert entries[0].uncertainty_marker is True
    assert "multiple glosses" in entries[0].original_gloss
    assert len(entries[0].entry_checksum) == 64
