from typing import Protocol


class LlmAdapter(Protocol):
    async def suggest_intent(self, untrusted_text: str) -> str: ...


class DisabledLlmAdapter:
    """The demo intentionally uses deterministic routing and no provider credentials."""

    async def suggest_intent(self, untrusted_text: str) -> str:
        return "disabled"
