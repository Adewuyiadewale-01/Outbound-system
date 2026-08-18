# Outreach Prep Workflow

## Purpose
- Run the `8:25 AM WAT` prep job for the LinkedIn connection-request block.
- Validate that execution is allowed and prepare a frozen local session cache for the `8:30 AM` runner.

## Sources of Truth
- [operation_brute_force.md](../SOURCES/operation_brute_force.md)
- `Operation Brute Force` -> `Outreach Control`
- `Operation Brute Force` -> `Prospects`
- `Operation Brute Force` -> `Outreach Sequence`

Source identity verification:
- `OBF_SHEET_URL` must be configured in the local environment.
- If the resource resolves to the wrong sheet, stop and report the blocker.

## Preconditions
- Today's `Outreach Control` row must exist.
- Today's `Outreach Control` row must be approved.
- Today's `Outreach Control` row must define the daily target.
- `Prospects` must contain enough prepared rows for the remaining target.
- Prepared prospect rows must include required reporting fields for the engaged person.
- `Outreach Sequence` structure must exist.

Required `Outreach Control` columns:
- `Date`
- `Base Target`
- `Rollover`
- `Effective Target`
- `Current Progress`
- `Status`
- `Approved`
- `Prospects Start Row`
- `Notes`

Required prospect fields:
- `ID`
- `Company`
- `Website`
- `Company LinkedIn`
- `Emp Count`
- `Source Tab`
- Chosen person's `Name`
- Chosen person's `Title`
- Chosen person's `LinkedIn`
- `Engaged Person`

## Command
```bash
python3 helpers/linkedin_outreach_session.py prepare-8_30-session --date <m/d/Y>
```

One-time setup command for the control tab:
```bash
python3 helpers/linkedin_outreach_session.py setup-outreach-control
```

## Data Resolution
- Approval state is read from `Operation Brute Force -> Outreach Control` for the target date.
- Target is read from `Effective Target` when present.
- If `Effective Target` is blank, target is computed as `Base Target + Rollover`.
- `Current Progress` is parsed from the control row's `Current Progress` field, defaulting to `0` when blank or malformed.
- `Prospects Start Row` is parsed as an optional 1-based `Prospects` row number; when present, rows above it are ignored for queue preparation.
- `Target remaining` is computed as `max(0, Effective Target - Current Progress)`.
- Queue is loaded only from `Operation Brute Force -> Prospects` through `load_prospect_queue(...)`, with `shuffle=False` during prep.
- Required field validation is performed by `_prospect_reporting_missing_fields(...)` against the selected engaged person.
- Runtime plan is loaded from `Operation Brute Force -> Outreach Sequence` after sequence generation writes its values.

## Execution Flow
1. Read today's approval state from `Operation Brute Force -> Outreach Control`.
2. Read target, rollover, current progress, and status from the control row.
3. Derive effective target from `Effective Target` or `Base Target + Rollover`.
4. Compute remaining target as `max(0, target - Current Progress)`.
5. Load prepared queue from `Operation Brute Force -> Prospects`; queue source is only `Prospects`, starting at `Prospects Start Row` when present.
6. Keep prep ordering stable by loading the queue without shuffle.
7. Block if queue is empty or shorter than target remaining.
8. Validate required fields for each selected prospect.
9. Generate and write enabled `Outreach Sequence` values:
   - `generate-batch-sizes`
   - `generate-activity-timing`
   - `generate-delay-seconds`
   - `generate-lead-diversions`
   - `generate-lead-diversion-seconds`
10. Load runtime plan from `Operation Brute Force -> Outreach Sequence`.
11. Write prepared-session cache to `state/outreach_sequences/<date>-prepared.json`.
12. Return prep summary.

## Target Rules
- Target comes from today's approved `Outreach Control` row.
- `Effective Target` wins when populated.
- Otherwise target is `Base Target + Rollover`.
- `Prospects` count does not redefine the target.
- Enabled `Outreach Sequence` row count does not redefine the target.
- `Prospects` and enabled slots only constrain whether prep can become ready.

## Person Selection
- Use `Person 1` by default.
- Use `Person 2` only when the row already says `Engaged Person = Person 2`.
- During required-field validation, blank `Engaged Person` is treated as `Person 1`.

## Prepared Cache Contract
Cache path:
- `state/outreach_sequences/<date>-prepared.json`

Cache must include:
- approval snapshot
- `Outreach Control` snapshot
- target total
- target remaining
- `Prospects Start Row` when present
- selected queue
- runtime plan

## Blockers
- Missing approval
- Missing or malformed `Outreach Control` row
- Empty `Prospects` queue
- Short `Prospects` queue
- Missing required reporting fields
- Sequence generation failure
- Sheet identity mismatch

## Output Contract
Prep summary heading:
- `LinkedIn outreach prep summary`

Required fields:
- `Ready`
- `Target remaining`
- `Prospects available`
- `Planned sends`
- `Blocked`

## Guardrails
- Do not run outreach execution from this job.
- Do not fetch from Lead DB.
- Do not improvise rows from any source other than `Prospects`.
- If prep is blocked, return the prep summary and stop.
