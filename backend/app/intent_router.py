from .schemas import Intent


class IntentRouter:
    def route(self, message: str) -> Intent:
        text = message.lower()
        if any(word in text for word in ("human", "agent", "representative")):
            return Intent.human_handoff
        if "transfer" in text or "move money" in text:
            return Intent.internal_transfer
        if "balance" in text or "account" in text:
            return Intent.balance
        if any(word in text for word in ("transaction", "spent", "purchase")):
            return Intent.transactions
        if "freeze" in text or "card" in text:
            return Intent.card_freeze
        if any(word in text for word in ("support", "dispute", "incorrect")):
            return Intent.support_ticket
        if "budget" in text or "spending" in text:
            return Intent.spending_insight
        return Intent.unknown
