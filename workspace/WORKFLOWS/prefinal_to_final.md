# Pre-final to Final Ranking

## Purpose
- Convert researched `Pre-final` rows into outreach-ready `Final` rows.
- Keep `Pre-final` as the seniority/research output.
- Use P1/P2 LinkedIn activity to decide whether P2 should become P1.
- Assign a lead category for outreach priority.

## Command
```bash
python3 scripts/prefinal_to_final.py
```

Safe validation without LinkedIn or sheet writes:
```bash
python3 scripts/prefinal_to_final.py --dry-run --activity-fixture <fixture.json>
```

Use a specific prepared outreach runtime plan:
```bash
python3 scripts/prefinal_to_final.py --sequence-date 2026-05-13
python3 scripts/prefinal_to_final.py --runtime-plan-path state/outreach_sequences/2026-05-13-prepared.json
```

## Execution Flow
1. Read non-empty `Pre-final` rows with at least one P1/P2 LinkedIn URL.
2. For live runs, load the prepared outreach runtime plan from `state/outreach_sequences/<date>-prepared.json`.
3. Select the next available `Pre-final` candidates up to the number of runtime plan slots.
4. Map one runtime plan slot to one selected `Pre-final` candidate row.
5. Read activity for P1 and P2 LinkedIn URLs only.
6. After each candidate row, apply that row's runtime plan:
   - `Lead Diversion`
   - `Lead Diversion Sec`
   - `Delay Sec`
7. Write `Not active` when activity is confidently read but no threshold is met.
8. Leave activity blank only when the read fails, times out, is inaccessible, or is uncertain.
9. Swap P1/P2 only when P2 has a higher activity level than P1.
10. Assign `Category`.
11. Sort rows by `Hyper`, `High`, `Alpha-medium`, `Medium`, then `Low`.
12. Overwrite values in `Final` from row 2 down.
13. Write local run state to `state/lead_exec_research/final_rankings/`.

## Activity Rules
- `Very active`:
  - at least 1 post within 7 days, or
  - at least 2 comments within 7 days, or
  - at least 2 reactions within 7 days
- `Active`:
  - at least 1 post within 14 days, or
  - at least 5 comments/reactions within 30 days
- `Not active`:
  - no qualifying activity
- Blank:
  - unreadable activity
  - uncertain classification

## Category Rules
- `Hyper`: two usable LinkedIns and at least one person is `Very active`.
- `High`: two usable LinkedIns and at least one person is `Active`.
- `Alpha-medium`: one usable LinkedIn and that person is `Very active`.
- `Medium`: one usable LinkedIn and that person is `Active`.
- `Low`: one or two usable LinkedIns but no known qualifying activity.

## Guardrails
- Do not inspect P3 activity in this workflow.
- Do not re-judge seniority; `Pre-final` P1/P2 order is the seniority baseline.
- Do not write activity notes columns.
- Do not write `Not active` for unknown or uncertain activity.
- Do not run live activity checks without a prepared runtime plan unless `--no-runtime-plan` is explicitly passed.
- Do not reuse one runtime slot for multiple candidate leads.
- If `Pre-final` has more candidate leads than runtime slots, process only the next candidates that fit the available slots.
