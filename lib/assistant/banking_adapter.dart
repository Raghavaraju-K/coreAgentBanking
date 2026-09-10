import 'models.dart';

abstract interface class BankingAdapter {
  Future<List<Account>> getAccounts(String customerId);
  Future<List<Transaction>> searchTransactions(
    String customerId, {
    String? query,
  });
  Future<String> createTransferDraft(String customerId, TransferDraft draft);
  Future<String> confirmTransfer(String customerId, String draftId);
  Future<String> freezeCard(String customerId, bool freeze);
  Future<String> createSupportTicket(String customerId, String category);
}

/// Replace this adapter with authenticated API clients in production.
/// It intentionally cannot execute a transfer without an explicit confirmation call.
class MockBankingAdapter implements BankingAdapter {
  final List<Account> _accounts = const [
    Account(
      id: 'checking-001',
      name: 'Everyday checking',
      maskedNumber: '•••• 4821',
      currency: 'USD',
      balance: 4280.50,
      availableBalance: 4210.50,
    ),
    Account(
      id: 'savings-001',
      name: 'Rainy day savings',
      maskedNumber: '•••• 0917',
      currency: 'USD',
      balance: 12640.00,
      availableBalance: 12640.00,
    ),
  ];

  final List<Transaction> _transactions = [
    Transaction(id: 't1', merchant: 'Hearth & Grain', category: 'Dining', amount: 24.80, date: DateTime(2026, 9, 8), isCredit: false, accountId: 'checking-001'),
    Transaction(id: 't2', merchant: 'Metro Transit', category: 'Transport', amount: 42.00, date: DateTime(2026, 9, 7), isCredit: false, accountId: 'checking-001'),
    Transaction(id: 't3', merchant: 'Northstar Payroll', category: 'Income', amount: 3200.00, date: DateTime(2026, 9, 5), isCredit: true, accountId: 'checking-001'),
    Transaction(id: 't4', merchant: 'Oak Market', category: 'Groceries', amount: 86.34, date: DateTime(2026, 9, 3), isCredit: false, accountId: 'checking-001'),
  ];

  @override
  Future<List<Account>> getAccounts(String customerId) async => _accounts;

  @override
  Future<List<Transaction>> searchTransactions(String customerId, {String? query}) async {
    if (query == null || query.trim().isEmpty) return _transactions;
    final normalized = query.toLowerCase();
    return _transactions.where((item) => '${item.merchant} ${item.category}'.toLowerCase().contains(normalized)).toList();
  }

  @override
  Future<String> createTransferDraft(String customerId, TransferDraft draft) async => 'draft-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<String> confirmTransfer(String customerId, String draftId) async => 'NS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

  @override
  Future<String> freezeCard(String customerId, bool freeze) async => freeze ? 'CARD-FROZEN' : 'CARD-ACTIVE';

  @override
  Future<String> createSupportTicket(String customerId, String category) async => 'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
}
