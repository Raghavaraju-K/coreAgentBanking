from .security import require_step_up


class PolicyGuard:
    def require_confirmation(self, confirmed: bool) -> None:
        if not confirmed:
            raise PermissionError("Explicit confirmation is required")

    def require_step_up(self, token: str) -> None:
        require_step_up(token)
