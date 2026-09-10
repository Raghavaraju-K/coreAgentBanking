enum MessageRole { assistant, user, system }
enum ActionKind { none, transferDraft, freezeCard, supportTicket }
enum ActionStatus { informational, draft, completed, failed }

class AuthenticatedSession {
  final String customerId;
  final String displayName;
  final bool isAuthenticated;

  const AuthenticatedSession({
    required this.customerId,
    required this.displayName,
    required this.isAuthenticated,
  });
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final ActionKind actionKind;
  final ActionStatus status;
  final Map<String, String> metadata;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.actionKind = ActionKind.none,
    this.status = ActionStatus.informational,
    this.metadata = const {},
  });
}

class Account {
  final String id;
  final String name;
  final String maskedNumber;
  final String currency;
  final double balance;
  final double availableBalance;

  const Account({
    required this.id,
    required this.name,
    required this.maskedNumber,
    required this.currency,
    required this.balance,
    required this.availableBalance,
  });
}

class Transaction {
  final String id;
  final String merchant;
  final String category;
  final double amount;
  final DateTime date;
  final bool isCredit;
  final String accountId;

  const Transaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
    required this.isCredit,
    required this.accountId,
  });

  String get signedAmount => '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}';
}

class TransferDraft {
  final String sourceAccountId;
  final String destinationLabel;
  final double amount;
  final DateTime date;
  final String note;

  const TransferDraft({
    required this.sourceAccountId,
    required this.destinationLabel,
    required this.amount,
    required this.date,
    required this.note,
  });
}

class AssistantResponse {
  final String text;
  final ActionKind actionKind;
  final ActionStatus status;
  final Map<String, String> metadata;

  const AssistantResponse({
    required this.text,
    this.actionKind = ActionKind.none,
    this.status = ActionStatus.informational,
    this.metadata = const {},
  });
}

class AuthorizationException implements Exception {
  final String message;
  const AuthorizationException(this.message);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}
