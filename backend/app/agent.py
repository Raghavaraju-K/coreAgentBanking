from uuid import UUID, uuid4

from .audit import AuditService
from .banking_adapters import MockBankingAdapter
from .intent_router import IntentRouter
from .conversation_service import ConversationService
from .human_handoff_service import HumanHandoffService
from .schemas import ActionState, AssistantAction, Intent, MessageRequest, MessageResponse, UiPayload
from .tool_registry import ToolRegistry


class AssistantAgent:
    def __init__(self, banking: MockBankingAdapter, audit: AuditService) -> None:
        self.banking = banking
        self.audit = audit
        self.router = IntentRouter()
        self.conversation_service = ConversationService()
        self.handoff = HumanHandoffService(audit)
        self.tools = ToolRegistry()

    @property
    def conversations(self) -> dict[UUID, list[MessageResponse]]:
        return self.conversation_service._messages

    def respond(self, customer_id: str, request: MessageRequest) -> MessageResponse:
        conversation_id = request.conversation_id or uuid4()
        intent = self.router.route(request.message)
        self.audit.record("assistant_request", customer_id, {"intent": intent.value})
        if intent == Intent.balance:
            payload = UiPayload(type="account_balance_card", data={"accounts": [item.model_dump() for item in self.banking.list_accounts(customer_id)]})
            response = self._response(conversation_id, "Here are your available balances.", ActionState.informational, intent, payload)
        elif intent == Intent.transactions:
            transactions = self.banking.list_transactions(customer_id, "checking-001")
            payload = UiPayload(type="transaction_list", data={"transactions": [item.model_dump(mode="json") for item in transactions]})
            response = self._response(conversation_id, "Here are your recent authorized transactions.", ActionState.informational, intent, payload)
        elif intent == Intent.internal_transfer:
            accounts = self.banking.list_accounts(customer_id)
            payload = UiPayload(type="transfer_form", data={"accounts": [item.model_dump() for item in accounts]})
            response = self._response(conversation_id, "I can prepare this transfer for your review. Nothing is sent from chat alone.", ActionState.requires_confirmation, intent, payload, "Review transfer")
        elif intent == Intent.card_freeze:
            payload = UiPayload(type="confirmation_card", data={"warning": "New purchases will be declined while frozen."})
            response = self._response(conversation_id, "I can help freeze your card after explicit confirmation and secure step-up authentication.", ActionState.requires_confirmation, intent, payload, "Review card action")
        elif intent == Intent.support_ticket:
            response = self._response(conversation_id, "I can open a support request with only the details needed for the issue.", ActionState.draft, intent, UiPayload(type="support_ticket_form"), "Open support request")
        elif intent == Intent.spending_insight:
            response = self._response(conversation_id, "Your recent visible spending is concentrated in Dining and Transport. This is informational only, not financial, tax, or investment advice.", ActionState.informational, intent, UiPayload(type="text", data={"disclaimer": "Informational insight only"}))
        elif intent == Intent.human_handoff:
            self.handoff.request(customer_id)
            response = self._response(conversation_id, "I will connect you with a human support agent.", ActionState.escalated, intent, UiPayload(type="human_handoff", data={"status": "requested"}), "Connect to support", action_type="handoff")
        else:
            response = self._response(conversation_id, "I can help with balances, transactions, transfers, cards, support, or spending insights.", ActionState.informational, intent, UiPayload(type="suggested_prompts", data={"prompts": ["Show my balance", "Show recent transactions", "Transfer money between my accounts"]}))
        self.conversation_service.append(conversation_id, response)
        return response

    def _response(self, conversation_id: UUID, text: str, state: ActionState, intent: Intent, payload: UiPayload | None, label: str | None = None, action_type: str = "navigate") -> MessageResponse:
        actions = [AssistantAction(label=label, type=action_type)] if label else []
        return MessageResponse(conversation_id=conversation_id, message_id=uuid4(), assistant_message=text, state=state, intent=intent, ui_payload=payload, actions=actions)
