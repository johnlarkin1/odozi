"""RSA keypair generation and JWT signing for load tests."""

import os
import sys
import time
import uuid

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from . import config

_private_key = None


def _load_private_key():
    global _private_key
    if _private_key is None:
        with open(config.PRIVATE_KEY_PATH, "rb") as f:
            _private_key = f.read()
    return _private_key


def make_load_test_token(user_id: str | None = None, expires_in: int = 3600) -> str:
    """Sign a JWT with the load test private key."""
    key = _load_private_key()
    now = int(time.time())
    payload = {
        "sub": user_id or f"loadtest_{uuid.uuid4().hex[:12]}",
        "iat": now,
        "exp": now + expires_in,
    }
    return jwt.encode(payload, key, algorithm="RS256")


def generate_keypair(output_dir: str | None = None) -> tuple[str, str]:
    """Generate an RSA keypair and write PEM files to output_dir."""
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(__file__), "..", "keys")

    os.makedirs(output_dir, exist_ok=True)

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    private_path = os.path.join(output_dir, "test_private.pem")
    public_path = os.path.join(output_dir, "test_public.pem")

    with open(private_path, "wb") as f:
        f.write(private_pem)
    with open(public_path, "wb") as f:
        f.write(public_pem)

    print(f"Generated keypair:\n  Private: {private_path}\n  Public:  {public_path}")
    return private_path, public_path


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "generate-keys":
        output = sys.argv[2] if len(sys.argv) > 2 else None
        generate_keypair(output)
    else:
        print("Usage: python -m common.auth generate-keys [output_dir]")
        sys.exit(1)
