from fastapi import Header, HTTPException, status

from .settings import settings


async def current_customer(authorization: str | None = Header(default=None)) -> str:
    """Demo bearer validation; replace with JWT/OAuth middleware in production."""
    if authorization != f"Bearer {settings.demo_bearer_token}":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    return "customer-demo-001"


def require_step_up(step_up_token: str) -> None:
    if step_up_token != "demo-step-up-approved":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Step-up authentication required")