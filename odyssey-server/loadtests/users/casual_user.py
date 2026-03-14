import random
from datetime import datetime, timedelta, timezone

from locust import HttpUser, between, task

from common.auth import make_load_test_token
from common.config import WAIT_MIN, WAIT_MAX
from common.entry_factory import make_entry_batch


class CasualUser(HttpUser):
    weight = 5
    wait_time = between(WAIT_MIN, WAIT_MAX)

    def on_start(self):
        self.token = make_load_test_token()
        self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(4)
    def sync_today(self):
        count = random.randint(1, 2)
        entries = make_entry_batch(count)
        self.client.post(
            "/entries",
            json={"entries": entries},
            headers=self.headers,
            name="/entries [daily POST]",
        )

    @task(3)
    def fetch_entries(self):
        self.client.get(
            "/entries?limit=50",
            headers=self.headers,
            name="/entries [GET recent]",
        )

    @task(2)
    def health_check(self):
        self.client.get("/healthz", name="/healthz")

    @task(1)
    def delete_entry(self):
        days_back = random.randint(1, 180)
        date = (datetime.now(timezone.utc) - timedelta(days=days_back)).strftime(
            "%Y-%m-%d"
        )
        self.client.delete(
            f"/entries/{date}",
            headers=self.headers,
            name="/entries/{date} [DELETE]",
        )
