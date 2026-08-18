# Outreach Execution Workflow

## Purpose
- Run the `8:30 AM-10:30 AM WAT` LinkedIn connection-request block from the prepared-session cache.
- Send connection requests without notes.
- Update `Prospects`, `Outreach Log`, local journal, and `Outreach Control` only after confirmed sends.

## Sources of Truth
- [operation_brute_force.md](../SOURCES/operation_brute_force.md)
- `Operation Brute Force` -> `Outreach Control`
- `Operation Brute Force` -> `Prospects`
- `Operation Brute Force` -> `Outreach Log`
- Local prepared-session cache from `8:25` prep

Source identity verification:
- `OBF_SHEET_URL` must be configured in the local environment.
- If the resource resolves to the wrong sheet, stop and report the blocker.

## Preconditions
- Prepared-session cache must exist and be ready.
- Today's approval snapshot in the cache must be approved.
- LinkedIn preflight must pass before any outward-facing action.
- Daily and weekly connection-request quota must have remaining capacity.

Prepared cache path:
- `state/outreach_sequences/<date>-prepared.json`

## Command
```bash
python3 helpers/linkedin_outreach_session.py run --date <m/d/Y> --require-prepared-session --no-notes
```

## Data Resolution
- Prepared-session cache is loaded from `state/outreach_sequences/<date>-prepared.json` by `_load_prepared_session(...)`.
- Execution uses the cache's `approval_state`, `outreach_control`, `queue`, and `runtime_plan` as the primary local snapshot when `--require-prepared-session` is set.
- Prepared cache queues are already filtered by `Outreach Control -> Prospects Start Row` when that value was present during prep.
- If the cache is missing, not ready, has the wrong date, empty queue, or empty runtime plan, execution stops before any LinkedIn action.
- LinkedIn quotas are read from `LinkedInSession().get_quotas()`.
- Daily progress is updated against the `Outreach Control` row number stored in the prepared cache.

## Execution Flow
1. Load prepared-session cache before execution.
2. Validate that the cache is ready, for the same date, and contains a non-empty queue and runtime plan.
3. Use the cache as the local snapshot for approval state, `Outreach Control` context, queue, and runtime plan.
4. Run LinkedIn preflight and quota checks.
5. For each selected prospect:
   - open the chosen LinkedIn profile
   - inspect activity before or after send according to `Activity Log Timing`
   - check `Posts`, then `Comments`, then `Reactions`
   - stop activity check at the first tab with activity within the past 30 days
   - send the connection request with notifications enabled and no note
   - write reporting fields only after LinkedIn returns successful send
6. Between leads, apply `Delay Sec` and `Lead Diversion` from the prepared runtime plan.
7. Update `Outreach Control` current progress and status using actual successful sends only.
8. Return runner summary.

## Activity Rules
- `Very active` = detected activity within the past 7 days.
- `Active` = detected activity within the past 30 days and none within 7 days.
- `Not active` = no detected activity within the past 30 days.
- Write `P1 Activity` or `P2 Activity` only for the engaged person and only when the live destination activity cell is blank.
- Existing manual/mobile-app activity values are authoritative and must not be overwritten by runtime activity checks.
- If `Activity Log Timing = before_conn`, write activity before attempting the send.
- If `Activity Log Timing = after_conn`, write activity only after confirmed successful send.

## Successful Send Updates
After a confirmed send, update `Prospects`:
- `Engaged Person`
- `Touch Method = LinkedIn`
- `Outreach Status = Connection Sent`
- `Outcome = Pending`
- `Date Queued = today`
- `Notes` with short send marker
- `P1 Activity` or `P2 Activity` for the engaged person only if the current sheet cell is blank

Then append `Outreach Log`:
- latest event inserted directly below header
- `Current Progress = Conn Request`
- `Touch Method = LinkedIn`
- `Outcome = Pending`
- activity detail embedded in `Notes`

Then update `Outreach Control`:
- increment only by actual successful sends
- never increment planned rows, skipped rows, failed sends, or blocked sessions
- set `Status = Done` when `Current Progress >= Effective Target`
- set `Status = Partial` when at least one confirmed send happened but the effective target was not reached

## Local Journal
Journal path:
- `state/outreach_journal/<date>.jsonl`

Logging order:
- write local per-lead records into the day's `jsonl`; the file is shared for the whole run, not one file per lead
- each confirmed lead writes a durable `lead_reporting_bundle` entry containing exact sheet mutation payloads for:
  - `Prospects`
  - `Outreach Log`
  - `Outreach Control`
- write `connection_request_confirmed` record
- write per-target sync status records for `Prospects`, `Outreach Log`, and `Outreach Control`
- if sheet sync fails after a real send, record `pending_sync` with the exact payload and return blocker summary

## Failure Handling
- Missing prepared cache: stop.
- LinkedIn preflight failure: stop before any send.
- Quota exhausted: stop without sending.
- Soft send failure: do not mark row sent and do not increment `Outreach Control`.
- `email_required_to_connect`: mark the prospect `Outreach Status = Requires email`, count it as skipped, and continue execution.
- Hard-stop error: stop whole session and report partial state.
- `Prospects` write failure after successful send: record pending sync and stop.
- `Outreach Log` write failure after successful send: record retryable pending sync and continue summary reporting.
- `Outreach Control` write failure after successful send: record pending sync and stop.

Hard-stop LinkedIn errors:
- `captcha`
- `restriction`
- `email_verify`
- `robot_check`
- `login`
- `daily_conn_req_limit`
- `weekly_conn_req_limit`
- `daily_profile_view_limit`

## Output Contract
Execution summary heading:
- `LinkedIn outreach summary`

Required fields:
- `Connection requests sent`
- `Skipped`
- `Blocked`
- `Quota remaining`
- `Engagement opportunities`

## Guardrails
- Do not run prep from this job.
- Do not send connection notes.
- Do not bypass `helpers/linkedin_outreach_session.py`.
- Do not update the daily approval checkbox.
- Do not touch the unengaged person block.
- Do not update upstream sourcing fields outside the owned reporting updates.
