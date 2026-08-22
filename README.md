# SnapClass — AI Powered Attendance System

SnapClass automates classroom attendance using face recognition and voice biometrics. This repository contains two logically separate applications:

1. **AI Attendance app** (root) — a **Streamlit** application. This is the main product: teacher/student login, subject/course management, face-photo attendance, voice-roll-call attendance, QR-code enrollment, and Supabase-backed storage.
2. **Landing page** (`landing/`) — a static marketing site served by a small **Flask** app. It links out to the deployed Streamlit app via a "Start AI Attendance" button.

The two frameworks are **not** merged into one process — Flask cannot host a stateful Streamlit app, and Streamlit cannot serve the landing page's static assets. They are run and deployed as two independent services.

## Folder structure

```
ai-attendance-project-app/
├── app.py                  # Streamlit entrypoint (AI Attendance app) — unchanged
├── requirements.txt        # Streamlit + AI/ML dependencies — unchanged
├── src/                    # AI Attendance app logic — unchanged
│   ├── components/         # Streamlit dialogs/widgets (enroll, share, voice, etc.)
│   ├── database/           # Supabase client + config (reads st.secrets)
│   ├── pipelines/          # face_pipeline.py, voice_pipeline.py (AI/ML logic)
│   ├── screens/            # home/teacher/student screens
│   └── ui/                 # base layout
├── landing/                 # Flask landing page (new)
│   ├── app.py               # Flask entrypoint, serves templates/index.html
│   ├── requirements.txt     # flask, gunicorn — isolated from root requirements.txt
│   ├── templates/
│   │   └── index.html
│   ├── static/
│   │   ├── css/style.css
│   │   ├── js/script.js
│   │   ├── fonts/
│   │   └── img/
│   └── vercel.json           # Vercel deployment config for this Flask app only
└── README.md
```

## Installation

Use two separate virtual environments — the Streamlit app's ML dependencies (dlib, librosa, etc.) are heavy and unrelated to the Flask app's needs.

**AI Attendance app (Streamlit):**
```bash
python3 -m venv .venv-app
source .venv-app/bin/activate
pip install -r requirements.txt
```

**Landing page (Flask):**
```bash
python3 -m venv .venv-landing
source .venv-landing/bin/activate
pip install -r landing/requirements.txt
```

## Environment variables / configuration

**Streamlit app** reads Supabase credentials from Streamlit secrets, not environment variables. A template already exists at `.streamlit/secrets.toml` (gitignored — never commit real values):

```toml
SUPABASE_URL = "your-supabase-project-url"
SUPABASE_KEY = "your-supabase-key"
```

Replace the placeholder values with your own Supabase project's Project URL and anon/public API key (Project Settings → API in the Supabase dashboard). Without real values here, `src/database/config.py` will fail on startup.

### Database schema

This app has no schema/migration tooling built in — `supabase/schema.sql` in this repo contains the exact `CREATE TABLE` statements the code in `src/database/db.py` expects (`teachers`, `students`, `subjects`, `subject_students`, `attendance_logs`, with the foreign keys needed for the app's embedded Supabase queries). On a fresh Supabase project: open the SQL Editor in your Supabase dashboard, paste the contents of `supabase/schema.sql`, and run it once.

**Landing page** optionally reads:

- `STREAMLIT_APP_URL` — the URL the "Start AI Attendance" buttons link to. Defaults to `https://snapclass.streamlit.app/` (the current production URL) if unset, so production behavior is unchanged. Set this locally if you want the landing page to point at a local Streamlit instance instead:
  ```bash
  export STREAMLIT_APP_URL=http://localhost:8501
  ```

## Running locally

**AI Attendance app (Streamlit)** — from the repo root:
```bash
source .venv-app/bin/activate
streamlit run app.py
```
Runs on `http://localhost:8501` by default.

**Landing page (Flask)** — from the repo root:
```bash
source .venv-landing/bin/activate
python landing/app.py
```
Runs on `http://localhost:5002` (as defined in `landing/app.py`). To link it to your local Streamlit instance instead of production, set `STREAMLIT_APP_URL` first (see above).

Both must be run as separate processes/terminals — there is no combined single-command startup, because Flask and Streamlit are different long-running servers.

## Deployment

The two apps deploy independently to different platforms:

- **Landing page → Vercel.** `landing/vercel.json` is a valid Vercel config, but it must be deployed with the project's **Root Directory set to `landing/`** in the Vercel dashboard (or via `vercel --cwd landing`), since `vercel.json`'s `"src": "app.py"` path is relative to itself. Set `STREAMLIT_APP_URL` as a Vercel environment variable only if you want it to differ from the default production URL.
- **AI Attendance app → Streamlit Community Cloud (or similar).** Vercel cannot host Streamlit — Streamlit needs a persistent WebSocket connection and stateful server process, which Vercel's serverless functions don't support. The app is currently deployed at `https://snapclass.streamlit.app/`; keep deploying it there (or another Streamlit-compatible host) separately from the landing page. Configure `SUPABASE_URL`/`SUPABASE_KEY` as Streamlit Cloud secrets in that deployment's settings.

## Known discrepancy (pre-existing, not changed)

`src/components/dialog_share_subject.py` builds student join-links using the domain `snapclass-main.streamlit.app`, while the landing page's default CTA links point to `snapclass.streamlit.app` (no `-main`). This mismatch predates this integration — I left both as-is per the instruction not to change existing AI Attendance functionality or landing page links unless required. Worth confirming which domain is the actual production deployment and aligning the other to match.
