from pathlib import Path

import pytest

from scripts.candidate_generation.config import load_config
from scripts.candidate_generation.models import DictionaryEntry


@pytest.fixture
def config():
    return load_config(Path("config/candidate_generation"))


def entry(identifier, word, definition, pos="n.", noun_class=None):
    return DictionaryEntry(
        id=identifier, dialect_id="dialect-luwanga", dialect_name="Luwanga", language_name="Luhya",
        word=word, word_normalized=word.casefold(), part_of_speech=pos, noun_class=noun_class,
        english_definition=definition,
    )


@pytest.fixture
def known_entries():
    return [
        entry("01", "ameno", "teeth"),
        entry("02", "amaatsi", "water"),
        entry("03", "amatsi", "water"),
        entry("04", "likofi", "navel; umbilicus; placenta"),
        entry("05", "likofi", "debt"),
        entry("06", "ingwe", "leopard"),
        entry("07", "ingwe", "a plant whose very severe ash is used for healing the wounds of boys who have been circumcised"),
        entry("08", "okhufwa", "die, be unconscious, be in a weak and apparently dying condition", "v.int."),
        entry("09", "okhufwa", "shine (of sunlight)", "v.int."),
    ]
