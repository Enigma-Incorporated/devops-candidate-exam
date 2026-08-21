"""Sentiment inference service.

Written by a researcher. It works on my laptop.
"""
import json
import os
import random
import time

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from scoring import score_text

# The model ships inside the image, next to the code.
MODEL_PATH = os.environ.get("MODEL_PATH", "model/model.json")

# Assignment fixture: the fixed sleep simulates a slow real-world model load
# without shipping large weights. It is not an endorsement of timer-based
# readiness; readiness should reflect whether initialization actually
# completed. The service cannot answer until the model is fully loaded.
MODEL_LOAD_SECONDS = int(os.environ.get("MODEL_LOAD_SECONDS", "60"))

app = FastAPI(title="sentiment-inference")

MODEL = None


@app.on_event("startup")
def load_model():
    global MODEL
    print(f"loading model from {MODEL_PATH} (takes ~{MODEL_LOAD_SECONDS}s)...")
    time.sleep(MODEL_LOAD_SECONDS)
    with open(MODEL_PATH) as f:
        MODEL = json.load(f)
    print(f"model {MODEL['name']}:{MODEL['version']} loaded")


class PredictRequest(BaseModel):
    text: str


@app.post("/predict")
def predict(req: PredictRequest):
    # Some model versions are slower or less stable than others; the model
    # artifact declares its own runtime behavior and we honor it here. This
    # simulates what a genuinely degraded model version does in production.
    behavior = MODEL.get("behavior", {})
    extra_latency_ms = behavior.get("extra_latency_ms", 0)
    error_rate = behavior.get("error_rate", 0.0)

    if extra_latency_ms:
        time.sleep(extra_latency_ms / 1000.0)
    if error_rate and random.random() < error_rate:
        raise HTTPException(status_code=500, detail="model inference failed")

    return score_text(MODEL, req.text)


@app.get("/")
def root():
    return {"service": "sentiment-inference", "model_version": MODEL["version"] if MODEL else None}
