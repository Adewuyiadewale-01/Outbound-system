# Final to Prospects Bridge

## Purpose
- Move ranked lead rows from `Final` into Operation Brute Force `Prospects`.
- Make the morning outreach queue available after approved-lead processing.
- Provide a recovery run before the next morning's outreach prep.

## Sources of Truth
- Lead executive sheet -> `Final`
- Operation Brute Force -> `Prospects`
- Local bridge state:
  - `state/lead_exec_research/bridges/<date>_<fingerprint>.json`

## Schedule
- `23:30 WAT`: bridge today's processed `Final` batch.
- `06:30 WAT`: recovery bridge for yesterday's processed `Final` batch.

## Commands
Evening run:
```bash
python3 scripts/lead_exec_research.py bridge-prefinal-to-prospects --target-date today
```

Morning recovery run:
```bash
python3 scripts/lead_exec_research.py bridge-prefinal-to-prospects --target-date yesterday
```

## Execution Flow
1. Read non-empty rows from `Final`.
2. Keep rows with `ID`, `Company`, `Category`, and at least one LinkedIn profile URL.
3. Build a stable fingerprint from the selected `Final` row content.
4. Check local bridge state for the target date and fingerprint.
5. Skip safely if the same batch was already bridged.
6. Skip rows whose `ID` already exists in `Prospects`.
7. Map `Final` fields into existing `Prospects` columns.
8. Write rows below the last meaningful `Prospects` row.
9. Save bridge state with status, target date, fingerprint, lead IDs, and write position.

## Mapping Rules
- Shared fields are copied directly:
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
- Do not copy `Use` into `Prospects`.
- Leave `Source Tab` blank when `Final` has it blank.
- `Engaged Person` is copied from `Final` when present, otherwise `Person 1` when P1 has a LinkedIn URL, otherwise `Person 2`.
- Operational fields start blank:
  - `Touch Method`
  - `Outreach Status`
  - `Outcome`
  - `Date Queued`
- `Notes` records the bridge source, category, and timestamp.

## Idempotency
- The bridge is keyed by target date and content fingerprint.
- The `23:30` run uses `today`.
- The `06:30` recovery run uses `yesterday`.
- If the same batch was already processed, the recovery run returns `skipped_already_bridged`.
- If rows already exist in `Prospects`, they are skipped by `ID`.

## Notifications
- Send Gmail only when rows are actually written.
- Include:
  - target date
  - rows written
  - fingerprint
  - write start row
  - lead IDs
- Empty `Final` is a quiet skip unless there is a failure.

## Guardrails
- Do not style, restructure, delete, create, resize, hide, or add validation to any Google Sheet tab.
- Only write values into existing `Prospects` columns/rows.
- Never duplicate a prospect ID.
- Never infer missing LinkedIn URLs.
