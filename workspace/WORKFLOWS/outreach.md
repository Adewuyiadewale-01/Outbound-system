# Outreach Workflow Index

This automation folder keeps the LinkedIn outreach workflow split by cron job.

## Jobs
- [prefinal_to_final.md](prefinal_to_final.md)
  - ranks `Pre-final` rows into `Final`
  - reads P1/P2 activity and assigns outreach priority category
- [prefinal_to_prospects.md](prefinal_to_prospects.md)
  - bridges ranked `Final` rows into Operation Brute Force `Prospects`
- [outreach_prep.md](outreach_prep.md)
  - `8:25 AM WAT`
  - validates approval, queue quality, target remaining, and sequence data
  - writes `state/outreach_sequences/<date>-prepared.json`
- [outreach_execution.md](outreach_execution.md)
  - `8:30 AM-10:30 AM WAT`
  - requires the prepared cache
  - sends LinkedIn connection requests without notes
  - writes confirmed-send reporting updates

## Runtime Assets
- `helpers/linkedin_outreach_session.py`
- `helpers/linkedin_helper.py`
- `helpers/outreach_helper.py`
- `helpers/sheets_helper.py`
- `scripts/launch-chrome.sh`

## External Runtime Dependencies
- Google Sheets credentials: `~/.openclaw/credentials/google-sheets.json`
- Chrome profile: `~/.openclaw/chrome-profile`
- Chrome CDP port: `18800`
