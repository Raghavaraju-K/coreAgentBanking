from uuid import UUID

from .schemas import MessageResponse


class ConversationService:
    def __init__(self) -> None:
        self._messages: dict[UUID, list[MessageResponse]] = {}

    def append(self, conversation_id: UUID, response: MessageResponse) -> None:
        self._messages.setdefault(conversation_id, []).append(response)

    def list(self, conversation_id: UUID) -> list[MessageResponse]:
        return list(self._messages.get(conversation_id, []))

    def summaries(self) -> list[tuple[UUID, int]]:
        return [(conversation_id, len(messages)) for conversation_id, messages in self._messages.items()]
