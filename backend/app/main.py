from uuid import UUID, uuid4

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status

from .agent import AssistantAgent
from .audit import AuditService
from .banking_adapters import MockBankingAdapter
from .policy_guard import PolicyGuard
from .schemas import Account, CardActionResponse, ConfirmActionRequest, ConversationSummary, LoginRequest, LoginResponse, MessageRequest, MessageResponse, Receipt, StepUpRequest, StepUpResponse, TicketRequest, TicketResponse, Transaction, TransferDraftRequest, TransferDraftResponse, UiPayload, UploadResponse
from .security import current_customer
from .settings import settings

app = FastAPI(title="Digital Banking Assistant API", version="1.0.0")
banking = MockBankingAdapter()
audit = AuditService()
agent = AssistantAgent(banking, audit)
policy = PolicyGuard()


@app.get("/health")
async def health() -> UiPayload:
    return UiPayload(type="text", data={"status": "ok"})


@app.post("/api/v1/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest) -> LoginResponse:
    if request.username != "demo" or request.password != "demo-password":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return LoginResponse(access_token=settings.demo_bearer_token)


@app.post("/api/v1/assistant/messages", response_model=MessageResponse)
async def assistant_message(request: MessageRequest, customer_id: str = Depends(current_customer)) -> MessageResponse:
    return agent.respond(customer_id, request)


@app.get("/api/v1/assistant/conversations", response_model=list[ConversationSummary])
async def conversations(customer_id: str = Depends(current_customer)) -> list[ConversationSummary]:
    return [ConversationSummary(id=conversation_id, message_count=len(messages)) for conversation_id, messages in agent.conversations.items()]


@app.get("/api/v1/assistant/conversations/{conversation_id}", response_model=list[MessageResponse])
async def conversation(conversation_id: UUID, customer_id: str = Depends(current_customer)) -> list[MessageResponse]:
    return agent.conversations.get(conversation_id, [])


@app.get("/api/v1/accounts", response_model=list[Account])
async def get_accounts(customer_id: str = Depends(current_customer)) -> list[Account]:
    return banking.list_accounts(customer_id)


@app.get("/api/v1/accounts/{account_id}/transactions", response_model=list[Transaction])
async def transactions(account_id: str, customer_id: str = Depends(current_customer)) -> list[Transaction]:
    try:
        return banking.list_transactions(customer_id, account_id)
    except (KeyError, PermissionError) as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found") from exc


@app.post("/api/v1/transfers/draft", response_model=TransferDraftResponse, status_code=status.HTTP_201_CREATED)
async def transfer_draft(request: TransferDraftRequest, customer_id: str = Depends(current_customer)) -> TransferDraftResponse:
    try:
        return banking.create_transfer_draft(customer_id, request)
    except (KeyError, PermissionError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@app.post("/api/v1/transfers/{transfer_id}/confirm", response_model=Receipt)
async def confirm_transfer(transfer_id: UUID, request: ConfirmActionRequest, customer_id: str = Depends(current_customer)) -> Receipt:
    policy.require_step_up(request.step_up_token)
    try:
        receipt = banking.confirm_transfer(customer_id, transfer_id, request.idempotency_key)
        audit.record("transfer_completed", customer_id, {"reference_id": receipt.reference_id})
        return receipt
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer draft not found") from exc


@app.get("/api/v1/transfers/{transfer_id}/receipt", response_model=Receipt)
async def transfer_receipt(transfer_id: UUID, customer_id: str = Depends(current_customer)) -> Receipt:
    for receipt in banking.completed_keys.values():
        if receipt.reference_id.endswith(transfer_id.hex[:10].upper()):
            return receipt
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")


@app.post("/api/v1/assistant/actions/{action_id}/confirm", response_model=UiPayload)
async def confirm_action(action_id: UUID, customer_id: str = Depends(current_customer)) -> UiPayload:
    audit.record("action_confirmation_requested", customer_id, {"action_id": str(action_id)})
    return UiPayload(type="authentication_required", data={"action_id": str(action_id), "message": "Complete secure confirmation in the banking app."})


@app.post("/api/v1/assistant/actions/{action_id}/step-up/verify", response_model=StepUpResponse)
async def verify_step_up(action_id: UUID, request: StepUpRequest, customer_id: str = Depends(current_customer)) -> StepUpResponse:
    audit.record("step_up_verified", customer_id, {"action_id": str(action_id), "method": request.method})
    return StepUpResponse(action_id=action_id, status="verified", step_up_token="demo-step-up-approved")


@app.post("/api/v1/assistant/uploads", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_file(file: UploadFile = File(...), customer_id: str = Depends(current_customer)) -> UploadResponse:
    if file.content_type not in {"image/jpeg", "image/png", "application/pdf"}:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Unsupported file type")
    return UploadResponse(id=uuid4(), status="received", filename=file.filename or "upload")


@app.post("/api/v1/cards/{card_id}/freeze", response_model=CardActionResponse)
async def freeze_card(card_id: str, request: ConfirmActionRequest, customer_id: str = Depends(current_customer)) -> CardActionResponse:
    policy.require_step_up(request.step_up_token)
    return CardActionResponse(card_id=card_id, status="frozen", masked_number="XXXX4821")


@app.post("/api/v1/cards/{card_id}/unfreeze", response_model=CardActionResponse)
async def unfreeze_card(card_id: str, request: ConfirmActionRequest, customer_id: str = Depends(current_customer)) -> CardActionResponse:
    policy.require_step_up(request.step_up_token)
    return CardActionResponse(card_id=card_id, status="active", masked_number="XXXX4821")


@app.post("/api/v1/support/tickets", response_model=TicketResponse, status_code=status.HTTP_201_CREATED)
async def create_ticket(request: TicketRequest, customer_id: str = Depends(current_customer)) -> TicketResponse:
    return banking.create_ticket(customer_id, request.category, request.description)


@app.get("/api/v1/support/tickets/{ticket_id}", response_model=TicketResponse)
async def ticket(ticket_id: UUID, customer_id: str = Depends(current_customer)) -> TicketResponse:
    return TicketResponse(id=ticket_id, reference=f"TKT-{ticket_id.hex[:8].upper()}", status="open")