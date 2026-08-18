# Task Manager Source

## Purpose
- Define Sentinel's live task-control system for daily execution, weekly targets, inbox intake, and task-key governance.

## Identity
- System name: `Task Manager`
- Human-facing display name: `Sentinel_Task_Manager`
- Configuration: set `TASK_MANAGER_URL` in the local environment (see `.env.example`).
- Authentication method: Google service account credentials via Sheets API / `gspread`

## Scope
### In Scope
- Daily execution planning and approval control.
- Weekly targets and progress tracking.
- Inbox capture for incoming tasks.
- Task-key registry and task-behavior governance.

### Out of Scope
- Outreach reporting outcomes that belong in the Operation Brute Force reporting sheet.
- Lead enrichment records that belong in the cleaned enrichment sheet.
- Temporary conversational memory.

## Components
- `Daily Actions`
- `Weekly Targets`
- `Inbox`
- `Tasks board`

## Schema
### Daily Actions
- Verified columns from CSV export:
  - `Date`
  - `Task Description`
  - `Owner`
  - `Task Behavior`
  - `Execution Mode`
  - `Priority`
  - `Start Time`
  - `Due Time`
  - `Origin Date`
  - `Current Progress`
  - `Progress Key`
  - `Status`
  - `Notes`
  - `Approval`

### Weekly Targets
- Verified columns from workbook:
  - `Week Starting`
  - `Week #`
  - `Target Description`
  - `Task Behavior`
  - `Status`
  - `Target Value`
  - `Current Progress`
  - `Progress Key`
  - `Notes`

### Inbox
- Verified columns from workbook:
  - `Received At`
  - `Raw Message`
  - `Parsed Task`
  - `Owner`
  - `Task Behavior`
  - `Priority`
  - `Status`
  - `Due Date`
  - `Notes`

### Tasks board
- Verified columns from workbook:
  - `Key`
  - `Task Name`
  - `Task Behaviour`
  - `Counts Toward Weekly Progress?`
  - `Default Owner`
  - `Notes`

## Allowed Values and Field Formats
### Daily Actions: verified from CSV export
- `Owner`
  - `[OC]`
  - `[AA]`
- `Task Behavior`
  - `Recurring`
  - `One-off`
  - `Unclear`
  - `Rolled`
- `Execution Mode`
  - `On a go`
  - `Randomized timing`
  - `Multiple timing`
- `Priority`
  - `High`
  - `Medium`
  - `Low`
- `Status`
  - `Rolled Over`
  - `Done`
  - `Skipped`
  - `Pending`
- `Approval`
  - `TRUE`
  - `FALSE`

### Daily Actions: field formats
- `Date`
  - Group header row only.
  - Display format: `m/d/YYYY`
  - Export/runtime format may be either formatted date text or spreadsheet serial number.
- `Task Description`
  - Free text.
  - Expected shape: short execution-focused task phrase.
  - Observed examples:
    - `Send 20 connection requests (warmup batch)`
    - `Check for new connection acceptances`
- `Owner`
  - Bracketed owner code string.
  - Observed format: `[OC]`, `[AA]`
- `Task Behavior`
  - Title-case categorical text from dropdown.
- `Execution Mode`
  - Human-readable categorical text phrase.
- `Priority`
  - Title-case categorical text.
- `Start Time`
  - Display format: `h:mm:ss AM/PM`
  - Export/runtime format may be either formatted time text or spreadsheet fractional-day serial.
- `Due Time`
  - Display format: `h:mm:ss AM/PM`
  - Export/runtime format may be either formatted time text or spreadsheet fractional-day serial.
- `Origin Date`
  - Display format: `m/d/YYYY`
  - Export/runtime format may be either formatted date text or spreadsheet serial number.
- `Current Progress`
  - Numeric field.
  - Observed values may be blank, integer-like, or decimal-like.
- `Progress Key`
  - Short stable key string.
  - Observed shape: lowercase snake-style token such as `conn_req`, `daily_report`, `req_withdraw`.
- `Status`
  - Human-readable categorical text from dropdown.
- `Notes`
  - Free text.
  - Expected shape: short operational context note, not long prose.
- `Approval`
  - Boolean checkbox field.
  - Display format: checked / unchecked.
  - Export/runtime format may appear as `TRUE`/`FALSE`, `1`/`0`, or equivalent checkbox values depending on read path.

### Weekly Targets: verified from workbook sample
- `Task Behavior`
  - `Recurring`
- `Status`
  - `Not Started`

### Weekly Targets: field formats
- `Week Starting`
  - Group header row only.
  - Display format: date.
  - Export/runtime format may be formatted date text or spreadsheet serial number.
- `Week #`
  - Group header row only.
  - Numeric field.
- `Target Description`
  - Free text.
  - Expected shape: short outcome-oriented target phrase.
- `Task Behavior`
  - Title-case categorical text from dropdown.
- `Status`
  - Human-readable categorical text from dropdown.
- `Target Value`
  - Numeric field.
  - May be integer or decimal.
- `Current Progress`
  - Numeric field.
  - May be blank, integer, or decimal.
- `Progress Key`
  - Short stable key string aligned with task registry.
- `Notes`
  - Free text operational note.

### Inbox: verified from workbook sample
- `Owner`
  - `[OC]`
- `Task Behavior`
  - `Recurring`
- `Priority`
  - `High`
  - `Medium`
- `Status`
  - `Promoted`
  - `New`

### Inbox: field formats
- `Received At`
  - Timestamp field.
  - Export/runtime format may be spreadsheet serial datetime or formatted datetime text.
- `Raw Message`
  - Free text.
  - Expected shape: near-verbatim inbound task/request text.
- `Parsed Task`
  - Free text.
  - Expected shape: normalized execution-focused task phrase.
- `Owner`
  - Bracketed owner code string.
- `Task Behavior`
  - Title-case categorical text from dropdown.
- `Priority`
  - Title-case categorical text from dropdown.
- `Status`
  - Human-readable categorical text from dropdown.
- `Due Date`
  - Date field.
  - Export/runtime format may be spreadsheet serial date or formatted date text.
- `Notes`
  - Free text.
  - Expected shape: short scheduling or processing note.

### Tasks board: verified from workbook sample
- `Task Behaviour`
  - `Recurring`
- `Counts Toward Weekly Progress?`
  - `Yes`
- `Default Owner`
  - `[OC]`

### Tasks board: field formats
- `Key`
  - Short stable key string.
  - Expected shape: lowercase snake-style token.
- `Task Name`
  - Free text.
  - Expected shape: short canonical noun phrase for the task family.
- `Task Behaviour`
  - Title-case categorical text from dropdown.
- `Counts Toward Weekly Progress?`
  - Yes/No style boolean text.
- `Default Owner`
  - Bracketed owner code string.
- `Notes`
  - Free text explaining task-family meaning or usage.

### Assumed but not fully verified
- Additional dropdown values may exist in Google Sheets even if they do not appear in the attached CSV export.
- Some free-text columns may have implicit length or style conventions not yet formally enforced in the sheet itself.

## Structural Semantics
### Daily Actions grouping model
- `Daily Actions` uses grouped date sections.
- The first row of a date group is a normal sheet row that acts as the day-group header.
- The day-group header row carries the `Date` value and the group-level `Approval` checkbox.
- Task rows under that group have blank `Date` cells in the sheet export.
- Task rows inherit group membership from the most recent non-empty `Date` row above them.
- The group ends when the next non-empty `Date` row appears or when separator rows begin.

### Daily Actions row types
- Day-group header row:
  - `Date` populated
  - `Task Description` blank
  - task-specific fields usually blank
  - `Approval` represents group-level approval state
- Task row:
  - `Date` blank in raw sheet rows
  - `Task Description` populated
  - `Approval` field exists but must not be treated as task-level approval control
- Separator row:
  - all cells blank
  - non-semantic spacing only

### Ordering rules
- Task rows are displayed under a day-group header.
- Execution order should be determined from `Start Time`, not raw row order alone, when packet generation or scheduler ordering matters.

### Additional grouped-tab semantics
- `Weekly Targets` also appears to use grouped rows where a week header row carries `Week Starting` and `Week #`, followed by target rows with those cells blank.
- `Inbox` does not currently show grouped execution sections in the workbook sample; it appears to behave as a flat intake list.
- `Tasks board` appears to behave as a flat registry table.

## Read Rules
- Resolve workbook by key first, then verify title matches `Sentinel_Task_Manager`.
- Verify required worksheet exists before reading.
- For grouped tabs such as `Daily Actions`, parsers must carry forward the most recent non-empty `Date` to associated task rows.
- For grouped tabs such as `Weekly Targets`, parsers should carry forward the most recent non-empty `Week Starting` and `Week #` to associated target rows.
- Reads must ignore fully blank separator rows.
- Workbook exports may expose dates and times as spreadsheet serial values, so parsing logic must support both formatted strings and numeric serials.

## Write Rules
- Writes should go through approved helper scripts rather than ad hoc free-form sheet mutation.
- Group-level approval writes must target only the day-group header row in `Daily Actions`.
- Task execution workflows may update task rows, but they must not treat task-row `Approval` cells as meaningful approval anchors.
- No workflow should silently create a missing day group during the `8:00 AM` approval gate.

## Group Creation Rules
- New daily groups should be built from recurring daily tasks, rolled tasks from the previous day, and Inbox tasks due today or explicitly moved into today.
- New weekly groups should be built from the standard weekly target structure unless Tony explicitly changes that structure.
- Workflows must not create duplicate day-group headers or duplicate week-group headers for the same period.
- Older day/week groups should remain as history unless Tony explicitly requests cleanup.

## Validation Rules
- Workbook key and resolved title must both match expected identity.
- `Daily Actions` must contain exactly one day-group header for a target date during approval processing.
- Required `Daily Actions` columns for approval processing are:
  - `Date`
  - `Task Description`
  - `Owner`
  - `Task Behavior`
  - `Start Time`
  - `Approval`
- Duplicate day-group headers for the same date are malformed state.
- Missing `Daily Actions` worksheet is malformed state.
- Missing `Weekly Targets`, `Inbox`, or `Tasks board` worksheets is malformed state for full Task Manager operation.

## Workflow Consumers
- `outreach_prep.md`
- `outreach_execution.md`
- Any workflow that reads or updates daily task execution state

## Verified Notes
- Verified directly from attached CSV export:
  `<local-download-directory>/Sentinel_Task_Manager - Daily Actions.csv`
- Verified directly from attached workbook:
  `<local-download-directory>/Sentinel_Task_Manager.xlsx`
- Verified row pattern:
  - header row for `4/17/2026` with blank task fields and `Approval=TRUE`
  - task rows under that date with blank `Date`
  - next header row for `4/18/2026`
- Verified workbook tabs:
  - `Weekly Targets`
  - `Daily Actions`
  - `Inbox`
  - `Tasks board`
- Verified `Weekly Targets` uses a week-header row followed by target rows with blank leading group cells.
- Verified `Inbox` is a flat intake table with parsed task fields.
- Verified `Tasks board` is a flat task-key registry.
- Verified that the export contains many fully blank rows after the visible task groups, so parsers must not treat trailing blank rows as data.

## Open Questions
- Exact dropdown universe for each tab may be broader than the values seen in the workbook sample.
- Need final confirmation on whether task-row `Approval` cells are always present by sheet schema even though group approval is anchored only on the date-header row.
- Need confirmation on whether `Weekly Targets` grouping is guaranteed for all future weeks or only current workbook layout.
- Need confirmation on whether any hidden tabs or named ranges are operationally important.
