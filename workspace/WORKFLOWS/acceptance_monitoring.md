# Acceptance Monitoring Workflow

## Purpose
- Detect when pending LinkedIn connection requests have been accepted, update the system state, and surface first-message drafts to Tony quickly.

## Scope
### In Scope
- Monitoring accepted LinkedIn connections by comparing pending `Outreach Log` records against LinkedIn's `Sent invitations` page
- Matching verified acceptances against pending `Outreach Log` connection-request rows
- Updating accepted outreach records to `Connected` in `Outreach Log`
- Transferring accepted leads into `Pipeline`
- Drafting first messages for Tony's approval
- Sending Tony a notification when new matched acceptances are found
- Local cadence control and duplicate suppression

### Out of Scope
- Sending first messages automatically
- Sending new connection requests
- Re-checking every pending prospect profile as the default method
- Daily approval-gate handling for the morning outreach block

## Sources of Truth
### Primary Sources
- [operation_brute_force.md](../SOURCES/operation_brute_force.md)
- LinkedIn `Sent invitations` page:
  - `https://www.linkedin.com/mynetwork/invitation-manager/sent/`
- `Operation Brute Force` -> `Outreach Log`
- `Operation Brute Force` -> `Pipeline`
- `Operation Brute Force` -> `Prospects` as read-only identity enrichment by `Prospect ID`

Source identity verification:
- `OBF_SHEET_URL` must be configured in the local environment.
- If the sheet resolves to the wrong id, stop and notify Tony

### Secondary Sources
- LinkedIn profile pages as verification only for prospects not found on the fully scraped `Sent invitations` page
- `Operation Brute Force` -> `Templates` for first-message drafts

## Preconditions and Gates
- There must be at least one `Outreach Log` row with `Current Progress = Conn Request`
- LinkedIn preflight must pass before any live browser check
- The workflow should respect local cadence state and skip if the next eligible check time has not been reached

Hard blockers:
- Chrome CDP unavailable
- LinkedIn restriction, CAPTCHA, login issue, robot check, email verification
- Operation Brute Force identity mismatch
- Failed accepted-state write for a matched prospect

## Model and Tooling Policy
- Primary cron/runtime model: `codex/gpt-5.3-codex`
- Fallback order when primary is unavailable: `codex/gpt-5.4`, then `codex/gpt-5.4-mini`
- Deterministic helper is mandatory:
  - `python3 helpers/linkedin_outreach_session.py acceptance-check`
- Browser actions must go through `helpers/linkedin_helper.py` via the runner
- Sheet writes must go through `helpers/outreach_helper.py`

## Inputs
- `date_value` in `m/d/Y`
- Operation Brute Force sheet URL
- Local acceptance state file:
  - `state/acceptance_monitoring/state.json`
- Pending `Outreach Log` rows with `Current Progress = Conn Request`

## Execution Flow
1. Cron runs the acceptance monitor command:
   `python3 helpers/linkedin_outreach_session.py acceptance-check --date <m/d/Y>`
2. The runner verifies Operation Brute Force sheet identity.
3. The runner loads pending `Outreach Log` rows with `Current Progress = Conn Request` and enriches them read-only from `Prospects` by `Prospect ID` when LinkedIn URL fields are needed.
4. If pending count is `0`, the runner records the next eligible check time locally, returns a skip summary, and exits without opening LinkedIn.
5. If the local cadence state says the next check is not yet due, the runner returns a cadence-skip summary and exits without opening LinkedIn.
6. If due, the runner opens LinkedIn and fully scrapes the `Sent invitations` page.
7. The runner accumulates unique sent-invite rows across scroll snapshots to avoid LinkedIn lazy-list undercounting.
8. The runner compares each pending prospect against the scraped sent invitations by normalized LinkedIn URL, then by exact unique normalized name.
9. Only pending prospects not found on the fully scraped sent page are opened directly for profile verification:
   - `already_connected` means accepted
   - `already_pending` means still pending
   - connectable or unavailable states mean declined/expired
   - unknown states are surfaced as verification errors
10. For each uniquely verified acceptance:
   - update the existing `Outreach Log` row to `Current Progress = Connected`
   - leave `Outcome` unchanged; connection acceptance is not a response outcome
   - append the accepted lead data into `Pipeline`
   - render the first-message draft from the approved `FM` templates
   - record the acceptance fingerprint in local state so it is not processed twice
11. If one or more matched acceptances were found, the automation sends Tony a Gmail notification immediately.
12. The runner stores the next eligible check time in local state and returns the summary.

## Decision Rules
- Primary detection method is subtractive monitoring from LinkedIn's `Sent invitations` page.
- Direct profile checks are allowed only for pending prospects missing from a fully accumulated sent-page scrape.
- Matching order for sent-page presence is strict:
  - LinkedIn profile URL
  - then exact unique normalized contact name
- If more than one pending row matches the same acceptance candidate, treat it as ambiguous and do not update the sheet
- This workflow is passive monitoring, so it does not depend on the daily morning approval gate
- Frequent cron invocation does not mean every run opens LinkedIn; cadence state decides whether the live check is due

## Failure and Blocker Handling
- Identity mismatch: stop and notify Tony
- No pending rows: skip quietly except for the summary message
- Cadence not due: skip quietly except for the summary message
- LinkedIn preflight failure: stop and notify Tony
- Accepted-state sheet sync failure: stop and notify Tony; do not mark the acceptance as seen locally
- Unmatched or ambiguous candidates: notify Tony in the summary, but do not guess or update any sheet row

## Outputs
- Acceptance summary message
- Gmail notification to Tony when new matched acceptances are found
- Updated `Outreach Log` rows for uniquely matched accepts
- New `Pipeline` rows for accepted/connected leads
- Draft first messages for Tony's approval
- Local acceptance state file

## Message and Packet Contracts
### Acceptance Summary Message
- Heading: `LinkedIn acceptance summary`
- Required fields:
  - `Status`
  - `Pending prospects`
  - `New accepts`
  - `Unmatched seen`
  - `Drafts prepared`
  - `Next eligible check`
  - `Blocked`

### Draft Block
- For each accepted prospect with a draft:
  - `Draft for <Contact Name> | <Company>`
  - `Template: <Template ID>`
  - rendered message body

### Gmail Notification
- Send only when `New accepts > 0`.
- Recipient: `fixmypresencenl1@gmail.com`
- Subject:
  - `LinkedIn acceptance found: <N> new`
- Body must include:
  - contact name
  - company
  - LinkedIn URL when available
  - whether the `Outreach Log` row was updated to `Connected`
  - whether a `Pipeline` row was created
  - first-message draft text when available
  - local log path
- Do not send a notification for:
  - `no_acceptances`
  - `skipped_cadence`
  - `skipped_no_pending`
  - send-window skips

## Logging and State Updates
- Local cadence/duplicate state:
  - `state/acceptance_monitoring/state.json`
- Required `Outreach Log` update for a confirmed acceptance:
  - `Current Progress = Connected`
  - `Last Action Date = <today>`
  - do not update `Outcome`
- Required `Pipeline` append:
  - accepted lead identity and engaged-contact fields
  - connected/current-progress status
- This workflow must never:
  - send the first LinkedIn message automatically
  - change `Date Queued`
  - overwrite upstream identity fields
  - guess ambiguous matches

## Monitoring and Reporting Hooks
- First-message approval workflow should consume the drafted messages from this runner output
- Reporting may count accepted connections from `Outreach Log` connected-state writes and `Pipeline`
- Unmatched acceptance candidates should be surfaced to Tony for manual review

## Commands and Tooling
- `python3 helpers/linkedin_outreach_session.py acceptance-check --date <m/d/Y>`
- `python3 helpers/linkedin_outreach_session.py acceptance-check --date <m/d/Y> --dry-run`

## Acceptance Checks
- No pending `Conn Request` rows in `Outreach Log` causes a safe skip without opening LinkedIn
- A not-yet-due cadence state causes a safe skip without opening LinkedIn
- A unique accepted connection updates `Outreach Log`, appends `Pipeline`, and drafts the first message
- An ambiguous acceptance candidate is reported but not written
- A duplicate candidate already seen in local state is skipped

## Operating Notes
- The `Sent invitations` page is the primary detector for this workflow.
- The scraper must accumulate unique rows across scroll snapshots; a single final LazyColumn DOM snapshot can undercount visible invites.
- Direct profile re-check is reserved for pending prospects absent from the accumulated sent-page scrape.
- Keep the runner deterministic and keep cron prompts short
