"""Timestamp validation shared by the static market snapshot job."""
from datetime import datetime, timedelta, timezone


def quote_status(timestamp: str, *, now: datetime | None = None,
                 max_age: timedelta = timedelta(minutes=30)) -> str:
    """Return LIVE only for a real, timezone-aware, recent provider timestamp.

    Raises ValueError for missing, malformed, timezone-naive, or materially
    future timestamps. Old observations remain available but are STALE.
    """
    if not isinstance(timestamp, str) or not timestamp.strip():
        raise ValueError("missing provider timestamp")
    try:
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("invalid provider timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("provider timestamp must include timezone")
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None or current.utcoffset() is None:
        raise ValueError("reference time must include timezone")
    age = current.astimezone(timezone.utc) - parsed.astimezone(timezone.utc)
    if age < timedelta(minutes=-5):
        raise ValueError("provider timestamp is in the future")
    return "LIVE" if age <= max_age else "STALE"
