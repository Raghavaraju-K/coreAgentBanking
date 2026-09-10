from datetime import datetime, timezone
from typing import Any


class AuditService:
    """Replace with an append-only, access-controlled audit sink in production."""

    def __init__(self) -> None:
        self.events: list[dict[str, Any]] = []

    def record(self, event: str, customer_id: str, metadata: dict[str, Any] | None = None) -> None:
        safe_metadata = {key: value for key, value in (metadata or {}).items() if key not in {"token", "password", "pin", "otp", "cvv"}}
        self.events.append({"event": event, "customer_id": customer_id, "metadata": safe_metadata, "at": datetime.now(timezone.utc).isoformat()})
