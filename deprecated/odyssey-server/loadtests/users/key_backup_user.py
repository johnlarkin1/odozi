from locust import HttpUser, between, task

from common.auth import make_load_test_token
from common.config import WAIT_MIN, WAIT_MAX
from common.entry_factory import make_key_backup


class KeyBackupUser(HttpUser):
    weight = 2
    wait_time = between(WAIT_MIN, WAIT_MAX)

    def on_start(self):
        self.token = make_load_test_token()
        self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(3)
    def store_key_backup(self):
        payload = make_key_backup()
        self.client.put(
            "/key-backup",
            json=payload,
            headers=self.headers,
            name="/key-backup [PUT]",
        )

    @task(5)
    def retrieve_key_backup(self):
        self.client.get(
            "/key-backup",
            headers=self.headers,
            name="/key-backup [GET]",
        )

    @task(1)
    def health_check(self):
        self.client.get("/healthz", name="/healthz")
