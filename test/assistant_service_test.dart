import 'package:flutter_test/flutter_test.dart';

import 'package:digital_banking_assistant/assistant/assistant_service.dart';
import 'package:digital_banking_assistant/assistant/banking_adapter.dart';
import 'package:digital_banking_assistant/assistant/models.dart';

class _TestAuthorizer implements AuthorizationPolicy {
  bool stepUpCalled = false;

  @override
  void requireAuthenticated(AuthenticatedSession session) {
    if (!session.isAuthenticated) throw const AuthorizationException('Not authenticated');
  }

  @override
  void requireStepUp(AuthenticatedSession session) {
    requireAuthenticated(session);
    stepUpCalled = true;
  }
}

void main() {
  const authenticated = AuthenticatedSession(customerId: 'customer-1', displayName: 'Ava Morgan', isAuthenticated: true);
  const unauthenticated = AuthenticatedSession(customerId: 'customer-1', displayName: 'Ava Morgan', isAuthenticated: false);

  test('rejects banking requests from an unauthenticated session', () async {
    final service = AssistantService(adapter: MockBankingAdapter(), authorizer: const PolicyAuthorizer());

    expect(() => service.respond(unauthenticated, 'show balance'), throwsA(isA<AuthorizationException>()));
  });

  test('routes a transfer request to a draft without executing it', () async {
    final service = AssistantService(adapter: MockBankingAdapter(), authorizer: const PolicyAuthorizer());

    final response = await service.respond(authenticated, 'I want to transfer money');

    expect(response.actionKind, ActionKind.transferDraft);
    expect(response.status, ActionStatus.draft);
  });

  test('rejects an invalid transfer before creating a draft', () async {
    final authorizer = _TestAuthorizer();
    final service = AssistantService(adapter: MockBankingAdapter(), authorizer: authorizer);
    final draft = TransferDraft(sourceAccountId: 'checking-001', destinationLabel: 'Savings', amount: 0, date: DateTime(2026, 9, 10), note: '');

    expect(() => service.confirmTransfer(authenticated, draft), throwsA(isA<ValidationException>()));
    expect(authorizer.stepUpCalled, isTrue);
  });

  test('requires step-up before confirming a valid transfer', () async {
    final authorizer = _TestAuthorizer();
    final service = AssistantService(adapter: MockBankingAdapter(), authorizer: authorizer);
    final draft = TransferDraft(sourceAccountId: 'checking-001', destinationLabel: 'Savings', amount: 25, date: DateTime(2026, 9, 10), note: 'Test');

    final reference = await service.confirmTransfer(authenticated, draft);

    expect(authorizer.stepUpCalled, isTrue);
    expect(reference, startsWith('NS-'));
  });
}