import random
from datetime import datetime, timedelta, timezone

from locust import HttpUser, between, task

from common.auth import make_load_test_token
from common.config import WAIT_MIN, WAIT_MAX
from common.entry_factory import make_entry_batch


class HeavySyncer(HttpUser):
    weight = 3
    wait_time = between(WAIT_MIN, WAIT_MAX)

    def on_start(self):
        self.token = make_load_test_token()
        self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(5)
    def batch_upload(self):
        count = random.randint(10, 50)
        entries = make_entry_batch(count)
        self.client.post(
            "/entries",
            json={"entries": entries},
            headers=self.headers,
            name="/entries [batch POST]",
        )

    @task(3)
    def fetch_entries(self):
        self.client.get(
            "/entries?limit=200",
            headers=self.headers,
            name="/entries [GET all]",
        )

    @task(2)
    def fetch_entries_since(self):
        since = (datetime.now(timezone.utc) - timedelta(days=7)).strftime(
            "%Y-%m-%dT%H:%M:%S.000Z"
        )
        self.client.get(
            f"/entries?since={since}",
            headers=self.headers,
            name="/entries?since= [GET]",
        )

    @task(1)
    def delete_old_entry(self):
        days_back = random.randint(30, 365)
        date = (datetime.now(timezone.utc) - timedelta(days=days_back)).strftime(
            "%Y-%m-%d"
        )
        self.client.delete(
            f"/entries/{date}",
            headers=self.headers,
            name="/entries/{date} [DELETE]",
        )
