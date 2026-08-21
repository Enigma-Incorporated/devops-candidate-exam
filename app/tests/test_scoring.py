import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from scoring import score_text

MODEL = json.loads((pathlib.Path(__file__).resolve().parents[1] / "model" / "model.json").read_text())


def test_positive_sentiment():
    result = score_text(MODEL, "This service is great, I love it")
    assert result["sentiment"] == "positive"
    assert result["score"] > 0


def test_negative_sentiment():
    result = score_text(MODEL, "Terrible and broken, full of bugs")
    assert result["sentiment"] == "negative"
    assert result["score"] < 0


def test_reports_model_version():
    result = score_text(MODEL, "anything")
    assert result["model_version"] == MODEL["version"]


def test_unknown_words_are_neutral():
    result = score_text(MODEL, "quantum flux capacitor")
    assert result["score"] == 0
    assert result["sentiment"] == "positive"
    assert result["matched_tokens"] == []
