# Lead Exec Research Workflow

## Purpose
- Pull one base batch from the Lead DB sheet.
- Scan it against the reusable research archive.
- When fresh-volume top-ups are enabled, add overlap-driven replacement waves until the configured fresh volume is restored or the source is exhausted.
- When top-ups are disabled, accept the single base batch as the complete preparation for the day even if most rows overlap the archive.
- Split the resulting review group into research batches of 5 companies.
- Research the top 2-3 executives per company.
- Reconcile discovered executives against employee rows already listed under each company.
- Write finalized contact data into the Prospects-style destination tab.

Codex remains the intelligence layer for fresh company/person research. The local script handles autonomous preparation, sheet I/O, archive matching/reuse, local run state, browser/search scraping, deterministic matching, and destination writes.

## Sources Of Truth
- Source table columns:
  - `ID`
  - `Company Name`
  - `Company Website`
  - `Company Linkedin`
  - `Person Name`
  - `Person Role`
  - `Person Email`
  - `Person Linkedin`
  - `Class`
- Destination table columns:
  - `ID`
  - `Company`
  - `Website`
  - `Company LinkedIn`
  - `Emp Count`
  - `Source Tab`
  - `P1 Name`
  - `P1 Title`
  - `P1 LinkedIn`
  - `P1 Email`
  - `P2 Name`
  - `P2 Title`
  - `P2 LinkedIn`
  - `P2 Email`
  - `P3 Name`
  - `P3 Title`
  - `P3 LinkedIn`
  - `P3 Email`
  - `Use`

## Command
Prepare the review queue:
```bash
python3 scripts/lead_exec_research.py prepare-review \
  --sheet-url "$LEAD_RESEARCH_SHEET_URL" \
  --source-tab Employee_db \
  --destination-tab Pre-final \
  --review-tab "Lead Review" \
  --credentials ~/.openclaw/credentials/google-sheets.json \
  --limit 50
```

Keep archive overlap detection but stop after one base batch:
```bash
python3 scripts/lead_exec_research.py prepare-review \
  --limit 50 \
  --disable-overlap-top-ups
```

After manual review, tick `Approved` in `Lead Review` for the leads that should be processed, then run the explicit Codex-research flow.

Freeze approved rows:
```bash
python3 scripts/lead_exec_research.py freeze-approved \
  --run-file state/lead_exec_research/runs/<run_id>.json \
  --sheet-url "$LEAD_RESEARCH_SHEET_URL" \
  --source-tab Employee_db \
  --destination-tab Pre-final \
  --review-tab "Lead Review" \
  --credentials ~/.openclaw/credentials/google-sheets.json
```

For sliced processing checkpoints, freeze one stable slice of the current group:
```bash
python3 scripts/lead_exec_research.py freeze-approved \
  --ignore-review-approval \
  --review-slice 1/3 \
  --run-file state/lead_exec_research/runs/<run_id>.json

python3 scripts/lead_exec_research.py freeze-approved \
  --ignore-review-approval \
  --review-slice 2/3 \
  --run-file state/lead_exec_research/runs/<run_id>.json

python3 scripts/lead_exec_research.py freeze-approved \
  --ignore-review-approval \
  --review-slice 3/3 \
  --run-file state/lead_exec_research/runs/<run_id>.json
```

Generate the next Codex research prompt:
```bash
python3 scripts/lead_exec_research.py research-prompt \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json \
  --research-batch-size 5
```

Codex then performs normal web research for the companies in the prompt and saves structured JSON under `state/lead_exec_research/research_results/`:
```json
{
  "results": [
    {
      "company": "Company Name",
      "executives": [
        {"name": "Person Name", "title": "Role", "linkedin_url": "LinkedIn URL if found"}
      ]
    }
  ]
}
```

Apply each research batch:
```bash
python3 scripts/lead_exec_research.py apply-research \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json \
  --research-file state/lead_exec_research/research_results/<batch>.json
```

Then reconcile researched executives against the source employee rows:
```bash
python3 scripts/lead_exec_research.py reconcile-existing \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json
```

Run/apply search tasks for any missing LinkedIn URLs, then write the final computation:
```bash
python3 scripts/lead_exec_research.py export-search-tasks \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json

node scripts/playwright_search_tasks.mjs \
  --input state/lead_exec_research/search_tasks/<timestamp>_search_tasks.json \
  --output state/lead_exec_research/search_results/<timestamp>_search_results.json \
  --limit 5 \
  --headed \
  --profile-root state/lead_exec_research/playwright_profiles \
  --profile-count 12 \
  --active-workers 4 \
  --min-delay-ms 5000 \
  --max-delay-ms 25000 \
  --captcha-replacement-delay-ms 40000

python3 scripts/lead_exec_research.py apply-search-results \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json \
  --search-result-file state/lead_exec_research/search_results/<timestamp>_search_results.json

python3 scripts/lead_exec_research.py write-computation \
  --computation-file state/lead_exec_research/computations/<snapshot_id>_computation.json \
  --write-start-row 2
```

Status/resume check:
```bash
python3 scripts/lead_exec_research.py status-approved --approval-threshold 20
python3 scripts/lead_exec_research.py resume-approved --approval-threshold 20
```

Preflight:
```bash
python3 scripts/lead_exec_research.py preflight \
  --sheet-url "$LEAD_RESEARCH_SHEET_URL" \
  --source-tab Employee_db \
  --destination-tab Pre-final \
  --credentials ~/.openclaw/credentials/google-sheets.json
```

The Google Sheet must be shared with:
- the service-account email listed in your local Google credentials.

## Review Gate
- `prepare-review` creates/appends rows in `Lead Review`.
- Review columns:
  - `Date`
  - `Primary Lane`
  - `Run ID`
  - `Company Name`
  - `Company Website`
  - `Emp Count`
  - `Approved`
  - `Use`
  - `Design Review Complete`
  - `Prep Wave`
  - `Overlap Status`
  - `Archive Entry ID`
- Hidden metadata columns may be present after `Emp Count`, but they are not part of the manual review surface.
- `Use` is filled manually during review and carried into `Pre-final` for approved leads.
- The automation must start with `status-approved` so it can skip processed groups, start fresh groups, or resume a partially completed computation.
- The automation must not write final data until Codex research, apply-research, reconciliation, and LinkedIn search handling have completed or the unresolved rows are intentionally skipped by the readiness guard.
- Normal operation uses the explicit flow: `freeze-approved -> research-prompt -> Codex research JSON -> apply-research -> reconcile/search -> write-computation`.
- Do not use the legacy `process-approved` shortcut for normal operation; the CLI blocks it unless `--force` is passed because it bypasses the Codex research layer.
- `Design Review Complete` is a group-level signal stored only on the date row. Unticked means the group is unreviewed or only partly reviewed.
- An unreviewed all-leads computation is archive-only: it cannot publish to `Pre-final`. Its review group is removed only after every reusable result is durably archived.
- Archive matches remain in the current review group and still require review. They are not researched again.

## Preparation Overlap Scan
- Durable index: `state/lead_exec_research/research_archive/index.json`.
- The preparation scan is detection-only. It never hydrates archived research, consumes an archive entry, or publishes a lead.
- Exact lead ID, normalized website domain, or normalized LinkedIn company slug can reuse an archive entry.
- Company-name-only matches are conflicts and require manual resolution; they are never reused automatically.
- Consumed entries are excluded from future preparations so the same person/company cannot be routed twice.
- Preparation always starts with one configured base batch.
- Every archive match or conflict in a wave creates one fresh-row shortfall.
- With fresh-volume top-ups enabled, the next wave is exactly that shortfall. Waves continue without a business cap until the fresh target is restored or the source is exhausted.
- Disable only replacement waves with `--disable-overlap-top-ups`. The base batch is then accepted for the day while its overlaps remain visible for review.
- Disable the scan explicitly with `--disable-overlap-scan`; otherwise it auto-enables whenever available archive entries exist.
- Inspect archive state with `python3 scripts/lead_exec_research.py archive-status`.

## Autonomous Preparation
- Dashboard config: `state/lead_prep_orchestration_config.json`.
- The short-lived watcher reads `autonomous_prep_enabled`, `prep_time`, `base_volume`, `overlap_scan_mode`, and `fresh_volume_top_up_mode`.
- Lead Review dashboard data is fetched into `state/lead_exec_research/dashboard_cache.json` once daily, ten minutes after the configured preparation time. A manual read-only refresh is also available.
- Only preparation and overlap detection are autonomous and model-free. Archive reuse and fresh intelligent research belong to `Process Approved Leads`.
- Dashboard approval changes are verified against the cached row identity, written to the native `Approved` checkbox, and followed by a cache refresh.
- Dashboard group completion changes update only the date row’s `Design Review Complete` checkbox.
- Manual research progress and notes are local dashboard state in `state/lead_exec_research/manual_research_progress.json`; they do not modify research content in the Sheet.
- The dashboard’s manual processing button runs one safe `resume-approved` step at a time.

## Codex Process Approved Leads Windows
- The external Codex-orchestrated flow is not scheduled by the dashboard or local watcher.
- Run 1: `18:00`. If the date group has at least 20 approved Design rows, process `--ignore-review-approval --review-slice 1/3`, then finalize the slice.
- Run 2: later checkpoint. Process `--ignore-review-approval --review-slice 2/3`, then finalize the slice.
- Run 3: later checkpoint. Process `--ignore-review-approval --review-slice 3/3`, then finalize the slice.
- Sliced finalize updates row-level statuses for each slice, but waits to mark the date group complete until all configured slices have finalized.
- Full fallback: if the Design threshold was not met at `18:00`, the later fallback can still use all-scope behavior to handle the group according to the lifecycle fallback rules.
- The dashboard reports the next window and countdown but does not create or modify those Codex automations.

## Email Notification
- Primary path: Codex sends the review-ready notification through the Gmail plugin after `prepare-review`.
- Recipient: `fixmypresencenl1@gmail.com`.
- The local script should usually be run with `--no-email` when Codex is orchestrating, because Codex handles notification directly.
- SMTP and `Notification Queue` remain fallback paths for standalone non-Codex runs.
- If SMTP fails, the script writes a pending row to `Notification Queue` by default.
- `scripts/lead_review_notification_apps_script.gs` can be pasted into the Google Sheet's Apps Script editor to send pending queue rows through `MailApp`.
- Use `--no-queue-notification` to disable the Apps Script queue fallback.

## Local State
Run files are stored in:
- `state/lead_exec_research/runs/<run_id>.json`
- `state/lead_exec_research/snapshots/<snapshot_id>_snapshot.json`
- `state/lead_exec_research/computations/<snapshot_id>_computation.json`
- `state/lead_exec_research/prompts/<prompt_id>_research_prompt.md`
- `state/lead_exec_research/search_tasks/<timestamp>_search_tasks.json`
- `state/lead_exec_research/search_results/<timestamp>_search_results.json`
- `state/lead_exec_research/research_archive/index.json`
- `state/lead_exec_research/migrations/<timestamp>_unreviewed_archive_migration.json`

Each run file contains:
- source snapshot and row numbers
- 50 selected lead groups for review
- review write status
- destination ID conflict warnings

Snapshot files contain:
- approved lead groups only
- original company rows and employee rows
- `Use` values from review
- source row numbers

Computation files contain:
- approved lead working records
- empty executive fields before research
- research outputs after Codex completes each batch
- programmatic reconciliation state
- search tasks for missing LinkedIn URLs
- eventual destination row payloads

The JSON file is intentionally the working memory for resume/debug. Use `status-approved` to inspect the current stage, counts, and next action before continuing.

## Grouping Rules
- A source row with `ID` and `Company Name` starts a new company group.
- Following rows without `ID` belong to the current company group when they contain employee/contact fields.
- A company may have zero employee rows.
- Employee rows can be messy; the reconciliation phase normalizes names, titles, emails, and LinkedIn URLs.

## Processing Flow
1. Read source and destination tabs.
2. Exclude source leads whose `ID` already exists in the destination tab.
3. Select one base batch and scan it against the research archive.
4. Add the required replacement waves only when fresh-volume top-ups are enabled.
5. Write the resulting group into `Lead Review` for manual approval.
6. Stop until approved rows are available.
7. Freeze approved rows into:
   - raw snapshot JSON
   - computation JSON
8. Generate Codex research prompts in batches from the computation JSON.
9. Codex researches the companies normally, using this prompt:
   ```text
   For each company below, find the names of the top 3 executives or most senior team members.

   Return one table with these columns:
   - Company
   - Names
   - Titles
   - Linkedin url if publicly available

   Only include people who are clearly connected to the company.
   ```
10. Store researched names, titles, and any surfaced LinkedIn URLs in computation JSON.
11. For each discovered executive without a LinkedIn URL:
   - match against employee names from the source group
   - if LinkedIn exists and is clean, use it
   - if LinkedIn exists but is messy, reconcile by checking name parts in the URL
   - if missing or low-confidence, create search tasks such as `"<name>" "<company>" linkedin`
   - run the search tasks in headed local Chrome via Playwright
   - scrape top 5 search results and select the highest-confidence profile
11. Choose P1 and P2 from finalized executives.
12. Write finalized approved company rows into the destination tab after coverage has been inspected.

## Playwright Search Resumability
- Google remains the first search engine because it has produced the best matches.
- The Playwright runner uses 12 persistent Chrome profiles, 4 active workers, and 8 standby queued profiles.
- Tasks are distributed into worker queues before the run starts.
- Random pacing is 5-25 seconds between searches.
- If a profile hits a Google CAPTCHA/automated-traffic page:
  - that profile is marked hot
  - Chrome is closed
  - the runner waits 40 seconds
  - the current task plus that worker's remaining queue are transferred to a standby profile
- If all profiles become hot, the result file records pending tasks and exits with status `paused_due_to_all_profiles_hot`.
- A paused search is resumable; do not mark the approved group processed until a later run finishes the pending tasks or the workflow intentionally writes only ready rows.

## Matching Rules
- Name matching uses normalized token overlap.
- Role matching boosts founder, CEO, managing director, owner, partner, president, CTO, COO, CFO, and head/director roles.
- LinkedIn URL reconciliation checks whether meaningful name parts appear in the URL.
- Search candidate scoring considers:
  - LinkedIn profile URL shape
  - candidate title/snippet containing the executive name
  - candidate title/snippet containing the company name
  - meaningful name parts in URL
  - role keywords in title/snippet

## Guardrails
- Do not modify existing outreach workflow files.
- Do not use paid APIs.
- Keep browser/search volume modest:
  - 50 companies per run
  - batches of 5
  - small random delays between search requests
- Prefer `--dry-run` before first live write.
- Do not mark source rows as processed unless a dedicated processed/status column is later added and explicitly configured.

## Output Contract
Console summary heading:
- `Lead exec research summary`

Required fields:
- `Run file`
- `Selected leads`
- `Batches`
- `Destination rows ready`
- `Rows written`
- `Dry run`
- `Errors`
