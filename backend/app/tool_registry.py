class ToolRegistry:
    """Allow-list for backend tools. User text and an LLM can never register tools."""

    APPROVED_TOOLS = frozenset({"list_accounts", "list_transactions", "create_transfer_draft", "create_support_ticket"})

    def is_allowed(self, tool_name: str) -> bool:
        return tool_name in self.APPROVED_TOOLS
