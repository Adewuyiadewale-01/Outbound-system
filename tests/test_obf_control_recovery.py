import sys
import unittest
from argparse import Namespace
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / "helpers"
if str(HELPERS) not in sys.path:
    sys.path.insert(0, str(HELPERS))

import linkedin_outreach_session as obf  # noqa: E402


class FakeWorksheet:
    def __init__(self):
        self.appended = []

    def append_row(self, row, value_input_option):
        self.appended.append((row, value_input_option))


class ObfControlRecoveryTests(unittest.TestCase):
    def test_weekend_guard_covers_saturday_and_sunday(self):
        self.assertTrue(obf._is_obf_weekend("2026-08-08"))
        self.assertTrue(obf._is_obf_weekend("2026-08-09"))
        self.assertFalse(obf._is_obf_weekend("2026-08-10"))

    def test_prepare_and_run_return_weekend_hold_without_touching_external_systems(self):
        prepare = obf.prepare_8_30_session(
            Namespace(creds="unused", date="2026-08-08", mock_daily_json=None, mock_queue_json=None)
        )
        run = obf.run(
            Namespace(
                creds="unused",
                date="2026-08-09",
                mock_daily_json=None,
                mock_queue_json=None,
                mock_quotas_json=None,
                dry_run=False,
            )
        )

        self.assertEqual(prepare["status"], "skipped_weekend")
        self.assertFalse(prepare["ready"])
        self.assertEqual(run["status"], "skipped_weekend")
        self.assertEqual(run["successful_sends"], 0)

    def test_auto_created_row_copies_latest_completed_target_and_start_row(self):
        worksheet = FakeWorksheet()
        headers = obf.OUTREACH_CONTROL_HEADERS
        rows = [
            {
                "Date": "8/4/2026",
                "Base Target": "20",
                "Rollover": "0",
                "Effective Target": "20",
                "Current Progress": "20",
                "Status": "Done",
                "Approved": "TRUE",
                "Prospects Start Row": "100",
            },
            {
                "Date": "8/5/2026",
                "Base Target": "12",
                "Rollover": "0",
                "Effective Target": "12",
                "Current Progress": "8",
                "Status": "Partial",
                "Approved": "TRUE",
                "Prospects Start Row": "120",
            },
        ]

        created = obf._append_auto_created_control_row(worksheet, headers, rows, "8/6/2026")

        self.assertEqual(created["target_source"], "previous_completed_row")
        self.assertEqual(created["source_date"], "8/4/2026")
        self.assertEqual(created["target"], 20)
        self.assertEqual(created["prospects_start_row"], 100)
        row = dict(zip(headers, worksheet.appended[0][0]))
        self.assertEqual(row["Date"], "8/6/2026")
        self.assertEqual(row["Base Target"], "20")
        self.assertEqual(row["Current Progress"], "0")
        self.assertEqual(row["Status"], "Planned")
        self.assertEqual(row["Approved"], "TRUE")

    def test_auto_created_row_uses_default_when_no_completed_row_exists(self):
        worksheet = FakeWorksheet()

        created = obf._append_auto_created_control_row(
            worksheet,
            obf.OUTREACH_CONTROL_HEADERS,
            [],
            "8/6/2026",
        )

        self.assertEqual(created["target_source"], "default")
        self.assertEqual(created["target"], obf.DEFAULT_TARGET)


if __name__ == "__main__":
    unittest.main()
