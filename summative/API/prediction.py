"""FastAPI service: predict median graduate debt (College Scorecard) and retrain on uploaded data."""
import io

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from retrain import FEATURES, MODEL_PATH, TARGET, RetrainError, clean_new_rows, retrain

model = joblib.load(MODEL_PATH)  # loaded from the repo at startup (Render's free disk is not persistent)

app = FastAPI(title="Graduate Debt Predictor",
              description="Predicts an institution's median graduate federal loan debt (USD) from College Scorecard data.")

# CORS: only browsers on these origins may call the API — the deployed Swagger UI on Render and the local
# Flutter web debug server. No "*" so arbitrary websites cannot use the API from a visitor's browser.
# Only GET (docs) and POST (predict/retrain) are needed; only the Content-Type header is sent.
# No cookies or auth are used, so credentials are disabled. Mobile apps are not browsers and are unaffected.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://graduate-debt-api-d2wk.onrender.com", "http://localhost:8080", "http://127.0.0.1:8080"],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)


class Institution(BaseModel):
    UGDS: int = Field(ge=1, le=200_000, description="Undergraduate enrolment")
    TUITIONFEE_IN: float = Field(ge=0, le=100_000, description="In-state tuition and fees (USD/year)")
    PCTPELL: float = Field(ge=0, le=1, description="Share of undergraduates with a Pell grant (0-1)")
    PCTFLOAN: float = Field(ge=0, le=1, description="Share of undergraduates with a federal loan (0-1)")
    UG25ABV: float = Field(ge=0, le=1, description="Share of undergraduates aged 25+ (0-1)")
    INEXPFTE: float = Field(ge=0, le=300_000, description="Instructional spending per full-time student (USD)")
    MD_EARN_WNE_P10: float = Field(ge=10_000, le=200_000, description="Median earnings 10 years after entry (USD)")
    AVGFACSAL: float = Field(ge=500, le=30_000, description="Average monthly faculty salary (USD)")
    CONTROL: int = Field(ge=1, le=3, description="1 public, 2 private non-profit, 3 private for-profit")
    PREDDEG: int = Field(ge=1, le=3, description="Predominant degree: 1 certificate, 2 associate, 3 bachelor's")
    REGION: int = Field(ge=1, le=9, description="IPEDS region code 1-9")

    model_config = {"json_schema_extra": {"example": {
        "UGDS": 2030, "TUITIONFEE_IN": 72690, "PCTPELL": 0.2014, "PCTFLOAN": 0.2802, "UG25ABV": 0.0024,
        "INEXPFTE": 31938, "MD_EARN_WNE_P10": 84956, "AVGFACSAL": 12404, "CONTROL": 2, "PREDDEG": 3, "REGION": 2}}}


def predict_one(row: dict) -> float:
    """Same as the notebook's predict_one, but uses the in-memory (possibly retrained) model."""
    return float(model.predict(pd.DataFrame([row])[FEATURES])[0])


@app.get("/")
def root():
    return {"message": "Graduate Debt Predictor. See /docs."}


@app.post("/predict")
def predict(inst: Institution):
    return {"predicted_median_debt_usd": round(predict_one(inst.model_dump()), 2)}


@app.post("/retrain")
async def retrain_endpoint(file: UploadFile = File(..., description="CSV with the 11 feature columns plus GRAD_DEBT_MDN")):
    global model
    try:
        new = pd.read_csv(io.BytesIO(await file.read()))
    except Exception:
        raise HTTPException(400, "File is not a readable CSV.")
    try:
        rows, skipped = clean_new_rows(new, _valid)  # same rules as /predict
    except RetrainError as e:
        raise HTTPException(400, str(e))
    model, info = retrain(model, rows)  # /predict uses the new model immediately
    return {"message": "Model retrained and now in use.", **info, "skipped_rows": skipped}


def _valid(r) -> bool:
    try:
        Institution(**{k: (int(r[k]) if k in ("UGDS", "CONTROL", "PREDDEG", "REGION") else r[k]) for k in FEATURES})
        return 0 <= r[TARGET] <= 200_000
    except Exception:
        return False
