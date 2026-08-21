"""Sentiment scoring against a loaded model artifact.

The "model" is a JSON document with word weights. It stands in for a real
model file (ONNX / safetensors / etc.) so the assignment stays CPU-friendly:
what matters operationally is that it is a versioned artifact the service
must load before it can serve.
"""
import re
from typing import Any, Dict

_WORD_RE = re.compile(r"[a-z']+")


def score_text(model: Dict[str, Any], text: str) -> Dict[str, Any]:
    weights = model["weights"]
    tokens = _WORD_RE.findall(text.lower())
    score = sum(weights.get(token, 0.0) for token in tokens)
    matched = [t for t in tokens if t in weights]
    return {
        "sentiment": "positive" if score >= 0 else "negative",
        "score": round(score, 3),
        "matched_tokens": matched,
        "model_name": model["name"],
        "model_version": model["version"],
    }
