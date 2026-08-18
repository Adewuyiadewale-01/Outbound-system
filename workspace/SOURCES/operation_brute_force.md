# Operation Brute Force Source

## Purpose
- Define the live outreach sheet used by the `8:25 AM` prep and `8:30 AM-10:30 AM` LinkedIn outreach block.

## Identity
- System name: `Operation Brute Force`
- Configuration: set `OBF_SHEET_URL` in the local environment (see `.env.example`).
- Authentication method: Google service account credentials via Sheets API / `gspread`

## Scope
### In Scope
- Morning outreach queue in `Prospects`
- Morning outreach event logging in `Outreach Log`
- Daily sequence planning in `Outreach Sequence`
- Approved message templates in `Templates`
- Daily summary counts in `Daily Metrics`

### Out of Scope
- Upstream lead sourcing from Lead DB
- Daily approval gating state from `Sentinel_Task_Manager`
- Browser automation behavior itself

## Components
- `Prospects`
- `Outreach Log`
- `Outreach Sequence`
- `Templates`
- `Daily Metrics`
- `Pipeline`

## Schema
### Prospects
- Workflow-required columns:
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
  - `P1 Activity`
  - `P2 Name`
  - `P2 Title`
  - `P2 LinkedIn`
  - `P2 Email`
  - `P2 Activity`
  - `Engaged Person`
  - `Touch Method`
  - `Outreach Status`
  - `Outcome`
  - `Date Queued`
  - `Notes`

### Outreach Log
- Runtime write contract columns:
  - `Prospect ID`
  - `Company`
  - `Person Engaged`
  - `Contact Name`
  - `Current Progress`
  - `Touch Method`
  - `Outcome`
  - `Last Action Date`
  - `Notes`

### Outreach Sequence
- Lead-slot table columns:
  - `Slot ID`
  - `Batch #`
  - `Activity Log Timing`
  - `Delay Sec`
  - `Lead Diversion`
  - `Lead Diversion Sec`
  - `Enabled`
- Batch table columns:
  - `Batch #`
  - `Batch Size`
  - `Enabled`

### Templates
- Runtime read contract columns:
  - `Template ID`
  - `Category`
  - `Template Name`
  - `Subject/Note`
  - `Message Body`
  - `Placeholders`
  - `Usage Rules`

### Daily Metrics
- Runtime write contract columns:
  - `Date`
  - `Conn Req Sent`
  - `Conn Accepted`
  - `First Messages`
  - `Follow-Ups`
  - `Profile Views`
  - `Engagement Opps`

## Allowed Values and Field Formats
### Prospects
- `ID`
  - Required text identifier.
  - Expected shape: short stable prospect id such as `001`.
- `Company`
  - Required free text.
  - Expected shape: canonical company name.
- `Website`
  - Required text.
  - Expected shape: full URL preferred.
- `Company LinkedIn`
  - Required text.
  - Expected shape: full company LinkedIn URL.
- `Emp Count`
  - Required text or numeric-style text.
  - Expected shape: employee range such as `51-200` or an explicit count.
- `Source Tab`
  - Required free text.
  - Expected shape: upstream source label used during prep.
- `P1 Name`, `P2 Name`
  - Free text person name.
- `P1 Title`, `P2 Title`
  - Free text job title.
- `P1 LinkedIn`, `P2 LinkedIn`
  - Full LinkedIn profile URL preferred.
  - Runtime may normalize missing protocol into `https://www...`.
- `P1 Email`, `P2 Email`
  - Free text email field.
- `P1 Activity`, `P2 Activity`
  - Dropdown field.
  - Allowed runtime values:
    - `Active`
    - `Very active`
    - `Not active`
  - Runtime meaning:
    - `Very active` = detected activity within the past 7 days
    - `Active` = detected activity within the past 30 days (and none within 7 days)
    - `Not active` = no detected activity within the past 30 days
  - Runtime check order:
    - `Posts`
    - `Comments`
    - `Reactions`
  - Runtime stops at the first of those tabs that shows activity within the past 30 days.
  - Manual/mobile-app activity values are authoritative for scoring.
  - Morning outreach writes only the engaged person's activity value, and only when that activity cell is blank.
  - Detailed activity metrics must be logged in `Outreach Log` notes, not in this dropdown column.
- `Engaged Person`
  - Allowed values:
    - `Person 1`
    - `Person 2`
  - Morning outreach defaults to `Person 1` if blank.
- `Touch Method`
  - For this workflow, required runtime value after a successful send:
    - `LinkedIn`
- `Outreach Status`
  - Observed workflow values:
    - `Queued`
    - `Connection Sent`
    - `Connected`
    - `First Message Sent`
    - `Following Up`
    - `Replied`
    - `Meeting Set`
    - `Not Interested`
    - `No Response`
    - `Withdrawn`
- `Outcome`
  - For this workflow:
    - `Pending` after successful connection request
    - `Accepted` after acceptance check
    - `Withdrawn` after withdrawal workflow
- `Date Queued`
  - Date field.
  - Runtime write format from outreach helper: `YYYY-MM-DD`
- `Notes`
  - Free text operational note.
  - Morning outreach may append a short send marker such as `8:30 connection request sent YYYY-MM-DD`.

### Outreach Control
- `Prospects Start Row`
  - Optional 1-based row number in `Prospects`.
  - When present, prep and execution queues ignore eligible prospects above this row.
  - The Final/Prospects bridge should set this to the first newly appended `Prospects` row for the day; the value remains manually editable.

### Outreach Log
- `Prospect ID`
  - Expected to match the `Prospects.ID` value.
- `Company`
  - Expected to match the `Prospects.Company` value.
- `Person Engaged`
  - Expected to match the `Prospects.Engaged Person` value.
- `Contact Name`
  - Expected to match the chosen engaged person's name from `Prospects`.
- `Current Progress`
  - Free text action label written by runtime.
  - Observed values:
    - `Conn Request`
    - `First Message`
    - `FU-1` through `FU-10`
- `Touch Method`
  - Expected value for this workflow: `LinkedIn`
- `Last Action Date`
  - Runtime write format: `YYYY-MM-DD`
- `Notes`
  - Free text detail field.
  - Connection-request rows may include:
    - `activity_timing=<instant|post_conn>; source_tab=<posts|comments|reactions>; within_7d=<n>; within_30d=<n>; total_visible=<n>`

### Outreach Sequence
- `Slot ID`
  - Required positive integer.
  - Stable daily slot index used by the morning session.
- `Batch #`
  - Positive integer.
  - In lead table, runtime assigns slot ownership to a batch.
  - In batch table, this is the batch identifier.
- `Activity Log Timing`
  - Allowed values:
    - `before_conn`
    - `after_conn`
- `Delay Sec`
  - Positive integer seconds.
- `Lead Diversion`
  - Allowed values:
    - `none`
    - `feed_scroll`
    - `engagement_trail`
    - `profile_drill`
    - `company_page_browse`
    - `recent_post_read`
- `Lead Diversion Sec`
  - Positive integer seconds or blank when diversion is `none`.
- `Enabled`
  - Boolean-style runtime flag.
  - Accepted truthy forms include `TRUE`, `Yes`, `1`, `enabled`.

### Templates
- `Template ID`
  - Short stable id such as `CR-01`, `FM-01`.
- `Category`
  - Observed categories used by helpers:
    - `Connection Request`
    - `First Message`
    - `Follow-Up`
    - `Email`
- `Message Body`
  - Free text template body using `{placeholder}` syntax.

## Structural Semantics
### Prospects
- `Prospects` is the morning execution queue for this workflow.
- This workflow does not fetch prospects from Lead DB.
- The chosen contact is derived from `Engaged Person`.
- If `Engaged Person` is blank, runtime uses `Person 1`.
- Rows with `Outreach Status` already in a downstream state are not eligible for fresh connection sending.

### Outreach Sequence
- `Outreach Sequence` is the daily behavior control table.
- The lead-slot table controls per-lead timing and diversion behavior.
- The batch table controls how enabled slots are partitioned into daily batches.
- Only enabled rows participate in daily generation and runtime loading.

## Read Rules
- `8:25 prep` reads `Prospects` as the only queue source for this phase.
- `8:25 prep` honors `Outreach Control.Prospects Start Row` when present, so newly bridged rows can be prioritized over earlier skipped or stale rows.
- `8:25 prep` reads `Outreach Sequence` structure and writes that day's generated values.
- `8:30 execution` reads the prepared-session cache first when `--require-prepared-session` is enabled.
- `8:30 execution` uses `Prospects` row content exactly as prepared; it must not infer missing company/contact identity fields.

## Write Rules
- Local-first journal:
  - path: `state/outreach_journal/<date>.jsonl`
  - write a durable local event record before sheet sync for each real successful stage-1 send
  - append separate sync-status entries for `Prospects` and `Outreach Log`
  - if `Outreach Log` sync fails after `Prospects` succeeds, treat it as retryable pending sync rather than stage-entry loss
- After a successful connection request, morning outreach owns these reporting writes on the engaged row:
  - `Engaged Person`
  - `Touch Method`
  - `Outreach Status`
  - `Outcome`
  - `Date Queued`
  - `Notes`
  - `P1 Activity` or `P2 Activity` for the engaged person only when the destination activity cell is blank
- Morning outreach must not overwrite the non-engaged person's columns.
- Morning outreach must not rewrite upstream identity fields such as `ID`, `Company`, `Website`, `Company LinkedIn`, `Emp Count`, `Source Tab`, or the untouched person block.
- `Prospects` is the first required sheet write for stage-1 pipeline entry.
- `Outreach Log` receives real action rows only, never planned actions.
- `Outreach Log` is the second write after `Prospects` stage-1 entry succeeds.
- `Outreach Log` inserts new rows directly below the header so the newest event is always nearest the top.
- Acceptance monitoring owns these `Outreach Log` and `Pipeline` writes for a matched acceptance:
  - update the existing `Outreach Log` row to `Current Progress = Connected`
  - append the accepted lead into `Pipeline`
- Acceptance monitoring must not change `Date Queued` when a request is accepted later.
- Overlapping `Outreach Log` fields are copied from `Prospects` by helper script `helpers/outreach_helper.py` via `log_outreach_event_from_prospect(...)`:
  - `Prospect ID`
  - `Company`
  - `Person Engaged`
  - `Contact Name`
  - `Touch Method`
  - `Outcome`
- Workflow-specific `Outreach Log` fields must still be explicitly written by runtime:
  - `Current Progress`
  - `Last Action Date`
  - `Notes`
- Sequence generators are the only writers for:
  - `Batch #`
  - `Batch Size`
  - `Activity Log Timing`
  - `Delay Sec`
  - `Lead Diversion`
  - `Lead Diversion Sec`

## Workflow Consumers
- `workspace/WORKFLOWS/outreach.md`
- `workspace/WORKFLOWS/acceptance_monitoring.md`
- `helpers/outreach_helper.py`
- `helpers/linkedin_outreach_session.py`
- Withdrawal checks
- Reporting workflow

## Operating Notes
- This source is downstream from upstream prep, but that upstream source is out of scope for this workflow.
- If a prospect row is missing required reporting fields for the engaged person, `8:25 prep` must notify Tony and stop the morning outreach block.
