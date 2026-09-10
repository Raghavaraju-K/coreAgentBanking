from datetime import date, datetime, timezone
from typing import Protocol
from uuid import UUID, uuid4

from .schemas import Account, Receipt, TicketResponse, Transaction, TransferDraftRequest, TransferDraftResponse


class BankingAdapter(Protocol):
    def list_accounts(self, customer_id: str) -> list[Account]: ...
    def list_transactions(self, customer_id: str, account_id: str) -> list[Transaction]: ...
    def create_transfer_draft(self, customer_id: str, request: TransferDraftRequest) -> TransferDraftResponse: ...
    def confirm_transfer(self, customer_id: str, transfer_id: UUID, idempotency_key: str) -> Receipt: ...
    def create_ticket(self, customer_id: str, category: str, description: str) -> TicketResponse: ...


class MockBankingAdapter:
    """Demo-only adapter. Replace this class with authenticated banking API clients."""

    def __init__(self) -> None:
        self.accounts = [
            Account(id="checking-001", name="Everyday checking", masked_number="XXXX4821", currency="INR", balance=128450.50, available_balance=121450.50),
            Account(id="savings-001", name="Rainy day savings", masked_number="XXXX0917", currency="INR", balance=326400.00, available_balance=326400.00),
        ]
        self.transactions = [
            Transaction(id="tx-1", merchant="Hearth & Grain", category="Dining", amount=1240.00, date=date(2026, 9, 8), transaction_type="debit", account_id="checking-001"),
            Transaction(id="tx-2", merchant="Metro Transit", category="Transport", amount=420.00, date=date(2026, 9, 7), transaction_type="debit", account_id="checking-001"),
            Transaction(id="tx-3", merchant="Northstar Payroll", category="Income", amount=132000.00, date=date(2026, 9, 5), transaction_type="credit", account_id="checking-001"),
        ]
        self.drafts: dict[UUID, tuple[str, TransferDraftRequest]] = {}
        self.completed_keys: dict[str, Receipt] = {}

    def _owned_account(self, customer_id: str, account_id: str) -> Account:
        if customer_id != "customer-demo-001":
            raise PermissionError("Account is not owned by this customer")
        for account in self.accounts:
            if account.id == account_id:
                return account
        raise KeyError("Account not found")

    def list_accounts(self, customer_id: str) -> list[Account]:
        if customer_id != "customer-demo-001":
            raise PermissionError("Customer is not authorized")
        return [account.model_copy() for account in self.accounts]

    def list_transactions(self, customer_id: str, account_id: str) -> list[Transaction]:
        self._owned_account(customer_id, account_id)
        return [item for item in self.transactions if item.account_id == account_id]

    def create_transfer_draft(self, customer_id: str, request: TransferDraftRequest) -> TransferDraftResponse:
        source = self._owned_account(customer_id, request.source_account_id)
        destination = self._owned_account(customer_id, request.destination_account_id)
        if source.id == destination.id:
            raise ValueError("Source and destination must be different accounts")
        if request.amount > source.available_balance:
            raise ValueError("Available balance is insufficient")
        draft_id = uuid4()
        self.drafts[draft_id] = (customer_id, request)
        return TransferDraftResponse(id=draft_id, source_account=source.masked_number, destination_account=destination.masked_number, amount=request.amount, fee=0, scheduled_date=request.scheduled_date, note=request.note)

    def confirm_transfer(self, customer_id: str, transfer_id: UUID, idempotency_key: str) -> Receipt:
        if idempotency_key in self.completed_keys:
            return self.completed_keys[idempotency_key]
        if transfer_id not in self.drafts or self.drafts[transfer_id][0] != customer_id:
            raise KeyError("Transfer draft not found")
        request = self.drafts[transfer_id][1]
        receipt = Receipt(reference_id=f"TRX-{transfer_id.hex[:10].upper()}", status="completed", amount=request.amount, completed_at=datetime.now(timezone.utc))
        self.completed_keys[idempotency_key] = receipt
        return receipt

    def create_ticket(self, customer_id: str, category: str, description: str) -> TicketResponse:
        if customer_id != "customer-demo-001":
            raise PermissionError("Customer is not authorized")
        ticket_id = uuid4()
        return TicketResponse(id=ticket_id, reference=f"TKT-{ticket_id.hex[:8].upper()}", status="open")
