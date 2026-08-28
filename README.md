# Outreach Automation

This repository contains a local-first automation toolkit for moving qualified leads through research, review, outreach, follow-up, and reporting workflows. It coordinates Google Sheets-backed queues with controlled browser automation and a local Electron dashboard.

## Before you run it

1. Create and activate a Python 3.10+ virtual environment.
2. Install runtime dependencies: `python3 -m pip install -r requirements.txt`.
3. Install the root JavaScript dependencies: `npm ci`.
4. Copy `.env.example` to `.env`, then set the required sheet URLs and local credential path. Core Python workflows load the root `.env` automatically; explicit process environment values take precedence.
5. Keep service-account JSON, browser profiles, generated state, lead exports, and workflow outputs outside version control. The root `.gitignore` protects these paths for a new repository.

## Verification

Run the Python suite with:

```bash
npm test
```

Run static checks after installing development dependencies with:

```bash
python3 -m pip install -r requirements-dev.txt
ruff check .
```

## Configuration and safe publishing

The code expects operational URLs and secrets through environment variables or Google Apps Script properties; no active account, sheet, browser profile, or webhook credential belongs in a public repository. See [docs/PUBLISHING.md](docs/PUBLISHING.md) for the pre-push checklist and [scripts/mobile_lead_app/SCRIPT_PROPERTIES.example.md](scripts/mobile_lead_app/SCRIPT_PROPERTIES.example.md) for the Apps Script configuration.

The local dashboard is designed to bind to loopback only. Do not expose it through a public interface without adding authentication and replacing the Electron renderer's legacy Node integration model.
