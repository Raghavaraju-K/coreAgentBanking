from .audit import AuditService


class HumanHandoffService:
    def __init__(self, audit: AuditService) -> None:
        self.audit = audit

    def request(self, customer_id: str) -> str:
        self.audit.record("human_handoff_requested", customer_id)
        return "requested"
