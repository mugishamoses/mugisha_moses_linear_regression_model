# Graduate Debt Predictor

**Author:** Mugisha Moses

## Mission and problem

My mission is to make higher education financially transparent so students are not trapped by debt.
Students and families rarely know how much debt graduates of a given school leave with before enrolling.
This project predicts an institution's **median graduate federal loan debt (USD)** from its cost, size, aid mix and outcomes,
so students and advisors can compare schools and flag ones whose debt burden is out of line.

## Dataset

U.S. Department of Education **College Scorecard — Most Recent Cohorts (Institution level)**: 6,272 U.S. institutions × 3,379 columns.
After cleaning: 2,699 institutions, 11 features (8 numeric: enrolment, in-state tuition, Pell share, loan share, share aged 25+,
instructional spend per student, median earnings 10 yrs after entry, faculty salary; 3 categorical: control, predominant degree, region)
and the target `GRAD_DEBT_MDN`. Source: https://collegescorecard.ed.gov/data/
(the 102 MB raw CSV is not committed; the cleaned subset is `summative/API/debt_data.csv`).

## API (Swagger UI)

https://graduate-debt-api-d2wk.onrender.com/docs

- `POST /predict` — JSON with the 11 features → predicted median debt
- `POST /retrain` — upload a CSV with the same columns (+ `GRAD_DEBT_MDN`); the model is refit and used immediately (sample: `summative/API/sample_retrain.csv`)

## Video demo

YOUTUBE_LINK_HERE

## How to run the mobile app

1. Install the Flutter SDK (3.x) and Android Studio, and create/start an Android emulator (or connect a phone with USB debugging). Check with `flutter doctor`.
2. Clone the repo: `git clone https://github.com/mugishamoses/mugisha_moses_linear_regression_model.git` and `cd mugisha_moses_linear_regression_model/summative/FlutterApp`
3. Install dependencies: `flutter pub get`
4. Run: `./run.sh` — opens the app in Chrome on port 8080 by default and falls back to an Android emulator/phone if Chrome is missing or the web run fails. To force Android: `flutter run -d emulator-5554` (or your device id from `flutter devices`).
5. Tap an example (**Public university**, **Private college**, **For-profit**) or fill the 4 sections yourself
   (11 inputs; shares are typed as percentages 0–100, e.g. `28` for 28 %), then tap **Predict**.
   Missing, wrong-type or out-of-range values are explained in the result card.
   The first request may take up to a minute while the free Render service wakes up.

UI designs for every screen state are in `summative/FlutterApp/design/` (S0 design system → S10 browser layout).

### Run the API / notebook locally (optional)

```bash
cd linear_regression_model/summative
uv sync
cd API && uv run uvicorn prediction:app --reload     # http://127.0.0.1:8000/docs
uv run jupyter notebook ../linear_regression/multivariate.ipynb
```
