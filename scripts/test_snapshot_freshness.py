import unittest
from datetime import datetime, timedelta, timezone

from snapshot_freshness import quote_status


class QuoteStatusTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 5, 12, 0, tzinfo=timezone.utc)

    def test_recent_observation_is_live(self):
        ts = (self.now - timedelta(minutes=2)).isoformat()
        self.assertEqual(quote_status(ts, now=self.now), "LIVE")

    def test_old_observation_is_stale(self):
        ts = (self.now - timedelta(days=100)).isoformat()
        self.assertEqual(quote_status(ts, now=self.now), "STALE")

    def test_missing_timestamp_is_rejected(self):
        with self.assertRaises(ValueError):
            quote_status("", now=self.now)

    def test_naive_timestamp_is_rejected(self):
        with self.assertRaises(ValueError):
            quote_status("2026-11-05T12:00:00", now=self.now)

    def test_materially_future_timestamp_is_rejected(self):
        ts = (self.now + timedelta(minutes=10)).isoformat()
        with self.assertRaises(ValueError):
            quote_status(ts, now=self.now)

    def test_small_clock_skew_is_tolerated(self):
        ts = (self.now + timedelta(minutes=2)).isoformat()
        self.assertEqual(quote_status(ts, now=self.now), "LIVE")


if __name__ == "__main__":
    unittest.main()
