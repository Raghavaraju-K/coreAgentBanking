# Flutter architecture

The Flutter client is a responsive Material 3 application targeting Android, iOS, and web.

## Layers

- `lib/assistant/models.dart`: domain entities and typed action states.
- `lib/assistant/banking_adapter.dart`: data boundary for banking APIs; the mock implementation is isolated here.
- `lib/assistant/assistant_service.dart`: application use cases, authorization policy boundary, and action sequencing.
- `lib/assistant/assistant_controller.dart`: GetX presentation/application controller. It owns reactive chat state and delegates business decisions to `AssistantUseCase`.
- `lib/assistant/assistant_binding.dart`: dependency composition root for GetX.
- `lib/assistant/assistant_screen.dart`: Flutter widgets only. It renders state and forwards user events to the controller.

The controller depends on `AssistantUseCase`, not a concrete adapter. A production FastAPI implementation can replace `AssistantService` in `AssistantBinding` without moving banking logic into widgets. The same screen and controller work on mobile and web because layout uses responsive Flutter constraints rather than platform-specific UI code.

## Production replacement

Implement `RemoteAssistantService implements AssistantUseCase` with an authenticated HTTP client and register it in `AssistantBinding`. Keep token storage, session expiry, structured payload parsing, and secure confirmation handoff outside widget code. The backend remains authoritative for authorization, ownership, limits, risk checks, and action execution.