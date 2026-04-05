"""Generate realistic entry payloads for load testing."""

import random
import string
from datetime import datetime, timedelta, timezone


def _random_hex_color() -> str:
    return f"#{random.randint(0, 0xFFFFFF):06X}"


def _random_timestamp(base: datetime | None = None) -> str:
    if base is None:
        base = datetime.now(timezone.utc)
    offset = random.randint(-3600, 3600)
    dt = base + timedelta(seconds=offset)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")


def _random_text(max_words: int = 20) -> str:
    words = [
        "grateful", "happy", "peaceful", "energized", "calm", "focused",
        "tired", "anxious", "hopeful", "motivated", "relaxed", "curious",
        "creative", "strong", "mindful", "present", "thankful", "inspired",
    ]
    count = random.randint(3, max_words)
    return " ".join(random.choices(words, k=count))


def make_entry(date: str | None = None) -> dict:
    """Generate a single realistic EntryInput dict (camelCase keys)."""
    now = datetime.now(timezone.utc)
    if date is None:
        days_back = random.randint(0, 365)
        entry_date = (now - timedelta(days=days_back)).strftime("%Y-%m-%d")
    else:
        entry_date = date

    ts = _random_timestamp(now)
    return {
        "entryDate": entry_date,
        "journalEntry": _random_text(30),
        "gratitude": _random_text(15),
        "win": _random_text(10),
        "tension": _random_text(10) if random.random() > 0.3 else None,
        "singleWordFeeling": random.choice([
            "happy", "calm", "tired", "anxious", "grateful", "excited",
        ]),
        "latitude": f"{random.uniform(25, 48):.6f}" if random.random() > 0.4 else None,
        "longitude": f"{random.uniform(-125, -70):.6f}" if random.random() > 0.4 else None,
        "city": random.choice(["Chicago", "New York", "Denver", "Austin", None]),
        "state": random.choice(["IL", "NY", "CO", "TX", None]),
        "country": "US" if random.random() > 0.2 else None,
        "feeling": random.randint(1, 10),
        "sleepQuality": random.randint(1, 10),
        "feelingColorHex": _random_hex_color(),
        "drinks": random.randint(0, 5),
        "stepCount": random.randint(1000, 15000) if random.random() > 0.3 else None,
        "walkingDistanceMeters": round(random.uniform(500, 10000), 1) if random.random() > 0.3 else None,
        "sleepHours": round(random.uniform(4, 10), 1) if random.random() > 0.3 else None,
        "screenTimeSeconds": round(random.uniform(1800, 28800), 0) if random.random() > 0.3 else None,
        "pickups": random.randint(10, 200) if random.random() > 0.5 else None,
        "createdAt": ts,
        "updatedAt": ts,
    }


def make_entry_batch(count: int = 10) -> list[dict]:
    """Generate a batch of entries with consecutive dates."""
    now = datetime.now(timezone.utc)
    start_offset = random.randint(1, 365)
    entries = []
    for i in range(count):
        date = (now - timedelta(days=start_offset - i)).strftime("%Y-%m-%d")
        entries.append(make_entry(date))
    return entries


def make_key_backup() -> dict:
    """Generate a key backup payload."""
    return {
        "encryptedKeyData": "".join(random.choices(string.ascii_letters + string.digits, k=512)),
        "keyDerivationSalt": "".join(random.choices(string.ascii_letters + string.digits, k=32)),
    }
