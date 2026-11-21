"""Retraining logic, shared by the /retrain endpoint and the command line.

Command line:  uv run python retrain.py new_rows.csv
"""
import sys
from pathlib import Path

import joblib
import pandas as pd
from sklearn.base import clone
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split

HERE = Path(__file__).parent
MODEL_PATH = HERE / "best_model.pkl"
DATA_PATH = HERE / "debt_data.csv"
TARGET = "GRAD_DEBT_MDN"
FEATURES = ["UGDS", "TUITIONFEE_IN", "PCTPELL", "PCTFLOAN", "UG25ABV",
            "INEXPFTE", "MD_EARN_WNE_P10", "AVGFACSAL", "CONTROL", "PREDDEG", "REGION"]


class RetrainError(ValueError):
    """Raised when the uploaded data can't be used."""


def clean_new_rows(new: pd.DataFrame, is_valid=lambda row: True) -> tuple[pd.DataFrame, int]:
    """Keep the model columns, drop non-numeric/blank rows and rows failing [is_valid]. Returns (rows, skipped)."""
    missing = set(FEATURES + [TARGET]) - set(new.columns)
    if missing:
        raise RetrainError(f"CSV is missing columns: {sorted(missing)}")
    rows = new[FEATURES + [TARGET]].apply(pd.to_numeric, errors="coerce").dropna()
    bad = [i for i, r in rows.iterrows() if not is_valid(r)]
    rows = rows.drop(index=bad)
    if rows.empty:
        raise RetrainError("No valid rows in the uploaded CSV.")
    return rows, len(new) - len(rows)


def retrain(model, new_rows: pd.DataFrame):
    """Best model is a RandomForest (not SGD), so refit on the original data plus the new rows.

    Returns (fitted_model, info). Saves the model and the combined data next to this file.
    """
    data = pd.concat([pd.read_csv(DATA_PATH), new_rows], ignore_index=True)
    X_tr, X_te, y_tr, y_te = train_test_split(data[FEATURES], data[TARGET], test_size=0.2, random_state=42)
    test_mse = mean_squared_error(y_te, clone(model).fit(X_tr, y_tr).predict(X_te))  # honest held-out score
    fitted = clone(model).fit(data[FEATURES], data[TARGET])  # final fit on every row
    joblib.dump(fitted, MODEL_PATH, compress=3)
    data.to_csv(DATA_PATH, index=False)
    return fitted, {"new_rows": len(new_rows), "total_rows": len(data), "test_mse": round(test_mse, 2)}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python retrain.py new_rows.csv")
    rows, skipped = clean_new_rows(pd.read_csv(sys.argv[1]))
    _, info = retrain(joblib.load(MODEL_PATH), rows)
    print({**info, "skipped_rows": skipped})
