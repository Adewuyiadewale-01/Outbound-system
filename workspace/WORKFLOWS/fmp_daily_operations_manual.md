# FMP Daily Operations Manual

This guide is for running and monitoring the daily FixMyPresence / Operation Brute Force outreach system. Times are Africa/Lagos / WAT.

## Daily Flow At A Glance

The system works in this order:

1. Lead Review queue is prepared.
2. Tony reviews and approves good leads.
3. Approved leads are researched and written into `Pre-final`.
4. `Pre-final` is ranked into `Final`.
5. `Final` is bridged into OBF `Prospects`.
6. OBF `Outreach Control` approves the next outreach target.
7. Morning outreach prep freezes the queue and runtime plan.
8. Morning outreach runner sends LinkedIn connection requests.
9. Acceptance monitor checks for accepted requests and drafts first messages.

If an earlier step is empty or blocked, later steps may safely skip.

## Your Phone Notification Schedule

Set these recurring reminders on your phone.

| Time | Reminder | What You Should Do |
| --- | --- | --- |
| 06:35 | Check Prospects recovery bridge | Confirm the 06:30 recovery did not fail. Usually safe to ignore if it says skipped or existing IDs. |
| 08:15 | Prepare Outreach Control | Open OBF `Outreach Control`. Create today's row if missing, set target/rollover, set `Prospects Start Row` if needed, and tick `Approved`. |
| 08:27 | Check outreach prep | Confirm 8:25 prep says ready, with target remaining, queue count, planned count, cache path, and runtime plan count. |
| 08:35 | Check outreach run started | Confirm 8:30 runner is not blocked by missing prep, LinkedIn login, quota, CAPTCHA, or restriction. |
| 10:35 | Check outreach result | Confirm sends, skips, blockers, quota remaining, and whether `Outreach Control` is `Done` or `Partial`. |
| Hourly | Check acceptance alerts | Watch for Gmail acceptance notifications and first-message drafts. Only act when new accepts are reported. |
| 14:05 | Review new lead queue | Open `Lead Review`. Approve good leads and fill `Use` for each approved row. Aim for at least 20 approved leads. |
| 16:05 | Second lead-review check | If the 14:00 queue failed or was skipped, check the 16:00 fallback. Continue approvals. |
| 22:05 | Check approved-lead processing | If at least 20 leads were approved, confirm processing completed or note the blocker. |
| 23:15 | Check Pre-final to Final | This automation has recently been paused. If enabled, confirm ranking wrote `Final`. |
| 23:35 | Check Final to Prospects bridge | Confirm new `Final` rows were copied into OBF `Prospects`, or that it skipped safely. |

## Morning Outreach Block

### 08:15 - Manual Approval Gate

Before the automation runs, check `Operation Brute Force -> Outreach Control`.

Required:

- Today's row exists.
- `Base Target` or `Effective Target` is set.
- `Rollover` is correct.
- `Current Progress` is correct, usually `0` before the run.
- `Prospects Start Row` is set if you want outreach to begin from a specific Prospects row.
- `Approved` is `TRUE`.
- `Status` is ready/planned, not blocked by a previous bad state.

If you forget this step, the 8:25 prep will block and 8:30 execution will not run.

### 08:25 - Outreach Prep

Automation: `OBF 8:25 Outreach Prep`

Command:

```bash
python3 helpers/linkedin_outreach_session.py prepare-8_30-session --date <m/d/Y>
```

What it does:

- Reads approval, target, rollover, progress, and status from `Outreach Control`.
- Loads the selected queue from OBF `Prospects`.
- Generates the `Outreach Sequence` runtime plan.
- Writes a prepared cache at `state/outreach_sequences/<date>-prepared.json`.

Success looks like:

- `Ready: True`
- `Target remaining` is greater than `0`, unless today's work is already done.
- `Prospects available` is at least target remaining.
- `Planned sends` equals target remaining.
- `Blocked: None`
- Runtime plan count equals planned count.

If blocked:

- Do not run outreach execution manually.
- Fix the blocker first: missing control row, not approved, no target, short queue, missing prospect fields, or sheet identity mismatch.

### 08:30-10:30 - Outreach Execution

Automation: `OBF 8:30 Outreach Run No Note`

Command:

```bash
python3 helpers/linkedin_outreach_session.py run --date <m/d/Y> --require-prepared-session --no-notes
```

What it does:

- Loads only the prepared cache from 8:25.
- Runs LinkedIn preflight and quota checks.
- Sends connection requests without notes.
- Updates `Prospects`, `Outreach Log`, local journal, and `Outreach Control` only after confirmed sends.

What you monitor:

- LinkedIn login/session is healthy.
- No CAPTCHA, robot check, restriction, email verification, or quota block.
- `Connection requests sent` matches the target or explains partial completion.
- `Outreach Control` progress increments only for real successful sends.

If blocked:

- Do not tick progress manually unless you have confirmed actual sends.
- Read the blocker first. Missing prepared cache means 8:25 prep failed. Login/CAPTCHA/restriction means the browser/LinkedIn account needs attention.

## Lead Supply Pipeline

### 14:00 - Prepare Lead Review Queue

Automations:

- `Prepare Lead Review Queue - 14:00`
- `Prepare Lead Review Queue - 16:00` fallback

Command:

```bash
python3 scripts/lead_exec_research.py prepare-review --no-email
```

What it does:

- Pulls the next 50 grouped company leads from Lead DB.
- Writes them to `Lead Review`.
- Stops for human review.

Your job:

- Open `Lead Review`.
- Approve only leads you actually want processed.
- Fill the `Use` field for approved rows.
- Try to approve at least 20 leads, because the 22:00 processor uses an approval threshold of 20.

If the 16:00 run says `review_skipped_already_prepared_today`, that is normal when 14:00 already prepared the queue.

### 22:00 / 23:00 - Process Approved Leads

Automations:

- `Process Approved Leads - 23:00`
- `Process Approved Leads`

Gate command:

```bash
python3 scripts/lead_exec_research.py status-approved --approval-threshold 20
```

Use three stable slices for high-volume groups:

```bash
python3 scripts/lead_exec_research.py status-approved --approval-threshold 20 --ignore-review-approval --review-slice 1/3
python3 scripts/lead_exec_research.py freeze-approved --ignore-review-approval --review-slice 1/3
python3 scripts/lead_review_lifecycle.py finalize --computation-file <COMPUTATION_FILE> --checkpoint first --threshold 20

python3 scripts/lead_exec_research.py status-approved --approval-threshold 20 --ignore-review-approval --review-slice 2/3
python3 scripts/lead_exec_research.py freeze-approved --ignore-review-approval --review-slice 2/3
python3 scripts/lead_review_lifecycle.py finalize --computation-file <COMPUTATION_FILE> --checkpoint fallback --threshold 20

python3 scripts/lead_exec_research.py status-approved --approval-threshold 20 --ignore-review-approval --review-slice 3/3
python3 scripts/lead_exec_research.py freeze-approved --ignore-review-approval --review-slice 3/3
python3 scripts/lead_review_lifecycle.py finalize --computation-file <COMPUTATION_FILE> --checkpoint fallback --threshold 20
```

What it does when threshold is met:

- Freezes the selected slice of current Lead Review rows.
- Performs Codex executive research.
- Reconciles with employee rows.
- Runs LinkedIn URL search tasks when needed.
- Writes researched rows into `Pre-final`.

Success looks like:

- Approved count is at least 20.
- Computation is written.
- Rows are written to `Pre-final`.
- Fingerprint is marked processed.
- Completion email may be sent.

If it says `skip_below_threshold`:

- Not enough leads were approved.
- Approve more rows, or accept that no new researched leads will move forward that night.

If it pauses due to pending search/CAPTCHA/hot profiles:

- Leave the run resumable.
- Do not mark the group processed until remaining search tasks are completed or intentionally skipped by the workflow guard.

## Ranking And Prospect Bridge

### 23:10 - Pre-final To Final Ranking

Automation: `Bridge Pre-final to Final - 23:10`

Current note:

- Recent memory says this automation is paused until explicitly enabled.

Command when enabled:

```bash
python3 scripts/prefinal_to_final.py
```

What it does:

- Reads researched `Pre-final` rows.
- Checks P1/P2 LinkedIn activity.
- Swaps P1/P2 only when P2 is more active.
- Assigns categories like `Hyper`, `High`, `Alpha-medium`, `Medium`, `Low`.
- Writes ranked rows to `Final`.

Your job:

- If it remains paused, expect the 23:30 prospects bridge to find no new `Final` rows.
- If enabled, check that `Final` has fresh ranked rows before the prospects bridge.

### 23:30 - Final To Prospects Bridge

Automation: `Bridge Pre-final to Prospects - 23:30`

Command:

```bash
python3 scripts/lead_exec_research.py bridge-prefinal-to-prospects --target-date today
```

What it does:

- Copies valid `Final` rows into OBF `Prospects`.
- Skips duplicate prospect IDs.
- Saves bridge state so the same batch is not copied twice.

Success looks like:

- Rows written is greater than `0`, or
- It safely skips with existing IDs / already bridged.

If it writes rows:

- Those rows become available for a future morning outreach queue.

### 06:30 - Prospects Recovery Bridge

Automation: `Bridge Pre-final to Prospects - 06:30 Recovery`

Command:

```bash
python3 scripts/lead_exec_research.py bridge-prefinal-to-prospects --target-date yesterday
```

What it does:

- Gives yesterday's `Final` batch one more chance to reach OBF `Prospects`.
- Safe to skip if already bridged or if IDs already exist.

Your job:

- Check only if morning outreach has no prospects or if the previous night looked blocked.

## Acceptance Monitoring

Automation: `OBF Hourly Acceptance Check`

Command:

```bash
python3 helpers/linkedin_outreach_session.py acceptance-check --date <m/d/Y>
```

What it does:

- Checks pending `Outreach Log` connection requests.
- Uses LinkedIn Sent Invitations as the primary detector.
- Updates accepted rows to `Connected`.
- Adds accepted leads to `Pipeline`.
- Drafts first messages.
- Sends Tony a Gmail notification only when new accepted connections are found.

Your job:

- Watch Gmail for `LinkedIn acceptance found: <N> new`.
- Review the first-message draft.
- Send or approve the first message manually. The automation does not send first messages.

Safe skips:

- No pending prospects.
- Cadence not due.
- No new accepts.

Action needed:

- LinkedIn login/CAPTCHA/restriction blocker.
- Ambiguous acceptance candidate.
- Sheet sync failure after confirmed acceptance.

## Daily Research For Messaging Leads

Automation: `Daily ChatGPT Lead Research`

What it does:

- Runs research for approved, unprocessed Messaging leads.
- Saves per-lead research artifacts and an aggregate report.

Your job:

- Check the output only when you are preparing messaging or when the automation reports a failure.
- If ChatGPT/browser timeouts happen, rerun only after confirming the previous output folder state.

Primary output folder:

```text
scripts/mobile_lead_app/chatgpt_research_workflow/output/research/
```

## What To Check In Each Sheet

### Lead DB / Lead Review Sheet

Use this for lead supply.

- `Lead Review`: approve/reject the 50 prepared leads.
- `Pre-final`: researched executive output.
- `Final`: ranked outreach-ready rows.

### Operation Brute Force

Use this for outreach operations.

- `Outreach Control`: daily target, approval, progress, status, and queue start row.
- `Prospects`: final queue used by outreach prep.
- `Outreach Sequence`: generated runtime plan.
- `Outreach Log`: record of connection requests and accepted connections.
- `Pipeline`: accepted connections ready for first-message/manual follow-up.
- `Templates`: first-message templates.

## Common Blockers And Fixes

| Blocker | Meaning | What To Do |
| --- | --- | --- |
| No `Outreach Control` row | Morning prep has no approved target source | Create today's row, set target, approve it. |
| Not approved | Prep is intentionally blocked | Tick `Approved` only when you want outreach to run. |
| Short Prospects queue | Not enough prepared prospects for target | Lower target, adjust `Prospects Start Row`, or wait for bridge to add rows. |
| Missing prepared cache | 8:30 execution cannot run | Fix and rerun 8:25 prep first. |
| LinkedIn login/CAPTCHA/restriction | Browser/account needs manual attention | Check PC immediately. Do not keep retrying blindly. |
| `skip_below_threshold` | Not enough Lead Review approvals | Approve at least 20 usable leads. |
| Already bridged / existing IDs | Duplicate-safe skip | Usually no action needed. |
| Acceptance ambiguous | Automation cannot safely match accepted lead | Review manually before updating sheets. |

## Minimum Daily Routine

If you only have time for the essential checks:

1. 08:15 - Approve today's `Outreach Control`.
2. 08:35 - Confirm outreach runner started or see blocker.
3. 10:35 - Confirm outreach result.
4. 14:05 - Approve Lead Review rows.
5. 22:05 - Confirm approved-lead processing.
6. 23:35 - Confirm new prospects were bridged, or skipped safely.
7. Anytime - Act on acceptance Gmail alerts.

## Rule Of Thumb

Do not force a later job when the earlier job that feeds it failed.

- No Lead Review approvals means no new `Pre-final`.
- No `Pre-final -> Final` means no new ranked leads.
- No `Final -> Prospects` means no new OBF queue.
- No approved `Outreach Control` means no morning prep.
- No 8:25 prepared cache means no 8:30 outreach execution.
