import os

HOST = os.environ.get("ODYSSEY_LOADTEST_HOST", "http://localhost:8080")
PRIVATE_KEY_PATH = os.environ.get(
    "ODYSSEY_LOADTEST_PRIVATE_KEY_PATH",
    os.path.join(os.path.dirname(__file__), "..", "keys", "test_private.pem"),
)
WAIT_MIN = float(os.environ.get("ODYSSEY_LOADTEST_WAIT_MIN", "1"))
WAIT_MAX = float(os.environ.get("ODYSSEY_LOADTEST_WAIT_MAX", "5"))
