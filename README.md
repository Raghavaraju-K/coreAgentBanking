# coreAgentBanking: Digital Banking Assistant

Original conversational banking demo with a Flutter client and FastAPI backend. The capability themes cover account inquiry, transaction support, safe internal transfers, card controls, disputes, spending insights, and human handoff. The experience does not copy third-party branding, interface designs, proprietary content, or code.

## Repository layout

- `lib/assistant`: Flutter feature module. `assistant_screen.dart` contains widgets, `assistant_controller.dart` contains GetX presentation state, `assistant_service.dart` contains application use cases, and `banking_adapter.dart` is the replaceable data boundary.
- `backend/app`: FastAPI contracts, deterministic intent router, policy guard, audit service, mock banking adapter, and routes.
- `backend/tests`: API security and workflow tests.

## Flutter

The Flutter app targets Android, iOS, and web. GetX is used for dependency injection and reactive presentation state. The default build uses isolated mock data and runs without a backend.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

To use FastAPI instead of the local mock service:

```powershell
flutter run --dart-define=USE_BACKEND=true --dart-define=ASSISTANT_API_BASE_URL=http://localhost:8000
```

For an Android emulator use `http://10.0.2.2:8000`; for a physical device use the development machine's LAN address. The remote client reads an `access_token` from `flutter_secure_storage` and falls back to the demo token only for local demo mode.

## FastAPI

```powershell
cd backend
C:/Users/ragha/AppData/Local/Programs/Python/Python314/python.exe -m pip install -r requirements.txt
C:/Users/ragha/AppData/Local/Programs/Python/Python314/python.exe -m uvicorn app.main:app --reload
```

The demo uses `Authorization: Bearer demo-token`. OpenAPI is available at `http://localhost:8000/docs`.

```powershell
cd backend
python -m pytest
```

Docker support is available with `docker compose up --build` after copying `.env.example` to `.env`.

## Chat contract

`POST /api/v1/assistant/messages` accepts a message and locale/timezone context. The response includes `assistant_message`, `state`, `intent`, an extensible `ui_payload`, and safe action metadata. Flutter maps payload types to presentation behavior without making authorization or banking decisions.

The backend currently demonstrates `account_balance_card`, `transaction_list`, `transfer_form`, `confirmation_card`, `support_ticket_form`, `text`, `suggested_prompts`, `authentication_required`, and `human_handoff` payloads.

## Security model

- Every customer-data route requires a bearer credential and server-side ownership checks.
- Account numbers are masked; secrets such as PIN, OTP, CVV, passwords, and full card numbers are never accepted by chat.
- Transfers are drafted before confirmation, require step-up validation, and use an idempotency key.
- The deterministic router treats user text as untrusted data. No LLM is enabled in demo mode.
- Audit events omit secret-like fields and are designed to be replaced by an append-only audit sink.
- The mock adapter is not production banking infrastructure.

## Production work remaining

Replace the demo bearer validator with JWT/OAuth middleware; persist conversations, actions, audit events, tickets, and idempotency keys in PostgreSQL; add real rate limiting, malware scanning, secure step-up integration, fraud/risk/limits checks, card and transfer processors, human support integration, and a provider-neutral LLM implementation that can only suggest intent or wording. Real banking APIs are required for balances, transactions, cards, bill pay, transfers, support, and receipts.
