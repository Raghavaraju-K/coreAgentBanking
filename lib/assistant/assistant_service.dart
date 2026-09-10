import 'banking_adapter.dart';
import 'models.dart';

abstract interface class AuthorizationPolicy {
  void requireAuthenticated(AuthenticatedSession session);
  void requireStepUp(AuthenticatedSession session);
}

class PolicyAuthorizer implements AuthorizationPolicy {
  const PolicyAuthorizer();

  @override
  void requireAuthenticated(AuthenticatedSession session) {
    if (!session.isAuthenticated) throw const AuthorizationException('Please sign in again to access banking details.');
  }

  @override
  void requireStepUp(AuthenticatedSession session) {
    requireAuthenticated(session);
    // Production implementation delegates to the existing PIN, biometric, or OTP flow.
  }
}

abstract interface class AssistantUseCase {
  Future<AssistantResponse> respond(AuthenticatedSession session, String input);
  Future<String> confirmTransfer(AuthenticatedSession session, TransferDraft draft);
  Future<String> confirmFreeze(AuthenticatedSession session, bool freeze);
  Future<String> openTicket(AuthenticatedSession session, String category);
}

class AssistantService implements AssistantUseCase {
  final BankingAdapter adapter;
  final AuthorizationPolicy authorizer;

  const AssistantService({required this.adapter, required this.authorizer});

  @override
  Future<AssistantResponse> respond(AuthenticatedSession session, String input) async {
    authorizer.requireAuthenticated(session);
    final text = input.trim();
    if (text.isEmpty) throw const ValidationException('Tell me what you would like help with.');
    final lower = text.toLowerCase();

    if (lower.contains('balance') || lower.contains('account')) {
      final accounts = await adapter.getAccounts(session.customerId);
      final summary = accounts.map((account) => '${account.name}: ${account.currency} ${account.availableBalance.toStringAsFixed(2)} available').join('\n');
      return AssistantResponse(text: 'Here are your available balances:\n$summary');
    }
    if (lower.contains('transaction') || lower.contains('spent') || lower.contains('purchase')) {
      final transactions = await adapter.searchTransactions(session.customerId, query: _extractSearch(lower));
      if (transactions.isEmpty) return const AssistantResponse(text: 'I could not find matching transactions. Try a merchant or category name.');
      final summary = transactions.take(5).map((item) => '${item.merchant}  ${item.signedAmount}').join('\n');
      return AssistantResponse(text: 'Here are the latest matching transactions:\n$summary');
    }
    if (lower.contains('transfer') || lower.contains('move money')) {
      return const AssistantResponse(
        text: 'I can prepare a transfer for you. Review the source, destination, amount, date, and note before any secure confirmation.',
        actionKind: ActionKind.transferDraft,
        status: ActionStatus.draft,
      );
    }
    if (lower.contains('freeze') || lower.contains('card')) {
      return const AssistantResponse(
        text: 'I can help with a temporary card freeze. Your card will decline new purchases while frozen, and you can unfreeze it later after secure confirmation.',
        actionKind: ActionKind.freezeCard,
        status: ActionStatus.draft,
      );
    }
    if (lower.contains('support') || lower.contains('dispute') || lower.contains('incorrect')) {
      return const AssistantResponse(
        text: 'I can open a support request and provide a tracking reference. I will only collect details needed for this issue.',
        actionKind: ActionKind.supportTicket,
        status: ActionStatus.draft,
      );
    }
    if (lower.contains('budget') || lower.contains('spending')) {
      return const AssistantResponse(text: 'Your recent visible spending is concentrated in Dining, Transport, and Groceries. This is an informational summary, not financial, tax, or investment advice.');
    }
    return const AssistantResponse(text: 'I can help with balances, transactions, transfers, cards, support requests, or spending summaries. What would you like to do?');
  }

  @override
  Future<String> confirmTransfer(AuthenticatedSession session, TransferDraft draft) async {
    authorizer.requireStepUp(session);
    if (draft.amount <= 0) throw const ValidationException('Enter an amount greater than zero.');
    final draftId = await adapter.createTransferDraft(session.customerId, draft);
    return adapter.confirmTransfer(session.customerId, draftId);
  }

  @override
  Future<String> confirmFreeze(AuthenticatedSession session, bool freeze) async {
    authorizer.requireStepUp(session);
    return adapter.freezeCard(session.customerId, freeze);
  }

  @override
  Future<String> openTicket(AuthenticatedSession session, String category) async {
    authorizer.requireAuthenticated(session);
    return adapter.createSupportTicket(session.customerId, category);
  }

  String? _extractSearch(String input) {
    for (final token in ['dining', 'groceries', 'transport', 'market', 'transit']) {
      if (input.contains(token)) return token;
    }
    return null;
  }
}
