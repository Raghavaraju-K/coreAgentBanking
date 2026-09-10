from datetime import date, datetime
from enum import Enum
from typing import Any, Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class ActionState(str, Enum):
    informational = "informational"
    draft = "draft"
    requires_confirmation = "requires_confirmation"
    requires_step_up = "requires_step_up"
    completed = "completed"
    failed = "failed"
    escalated = "escalated"


class Intent(str, Enum):
    balance = "balance"
    transactions = "transactions"
    internal_transfer = "internal_transfer"
    card_freeze = "card_freeze"
    support_ticket = "support_ticket"
    spending_insight = "spending_insight"
    human_handoff = "human_handoff"
    unknown = "unknown"


class UiPayload(BaseModel):
    type: str
    data: dict[str, Any] = Field(default_factory=dict)


class AssistantAction(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    label: str
    type: Literal["navigate", "confirm", "retry", "handoff"]


class ChatContext(BaseModel):
    locale: str = "en-IN"
    timezone: str = "Asia/Kolkata"


class MessageRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    conversation_id: UUID | None = None
    message: str = Field(min_length=1, max_length=2000)
    context: ChatContext = Field(default_factory=ChatContext)


class MessageResponse(BaseModel):
    conversation_id: UUID
    message_id: UUID
    assistant_message: str
    state: ActionState
    intent: Intent
    ui_payload: UiPayload | None = None
    actions: list[AssistantAction] = Field(default_factory=list)


class Account(BaseModel):
    id: str
    name: str
    masked_number: str
    currency: str
    balance: float
    available_balance: float


class Transaction(BaseModel):
    id: str
    merchant: str
    category: str
    amount: float
    date: date
    transaction_type: Literal["debit", "credit"]
    account_id: str


class TransferDraftRequest(BaseModel):
    source_account_id: str
    destination_account_id: str
    amount: float = Field(gt=0, le=1_000_000)
    scheduled_date: date
    note: str = Field(default="", max_length=140)


class TransferDraftResponse(BaseModel):
    id: UUID
    state: ActionState = ActionState.requires_confirmation
    source_account: str
    destination_account: str
    amount: float
    fee: float
    scheduled_date: date
    note: str


class ConfirmActionRequest(BaseModel):
    idempotency_key: str = Field(min_length=8, max_length=128)
    step_up_token: str = Field(min_length=1)


class Receipt(BaseModel):
    reference_id: str
    status: Literal["completed"]
    amount: float
    completed_at: datetime


class TicketRequest(BaseModel):
    category: Literal["incorrect_transaction", "card_issue", "account_issue"]
    description: str = Field(min_length=1, max_length=1000)


class TicketResponse(BaseModel):
    id: UUID
    reference: str
    status: Literal["open"]


class StepUpRequest(BaseModel):
    method: Literal["biometric", "pin", "otp"]


class ConversationSummary(BaseModel):
    id: UUID
    message_count: int


class UploadResponse(BaseModel):
    id: UUID
    status: Literal["received"]
    filename: str


class CardActionResponse(BaseModel):
    card_id: str
    status: Literal["active", "frozen"]
    masked_number: str


class StepUpResponse(BaseModel):
    action_id: UUID
    status: Literal["verified"]
    step_up_token: str


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=1, max_length=256)


class LoginResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
