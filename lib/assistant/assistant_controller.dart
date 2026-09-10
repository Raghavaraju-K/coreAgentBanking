import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'assistant_service.dart';
import 'models.dart';

class AssistantController extends GetxController {
  final AssistantUseCase service;
  final AuthenticatedSession session;
  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessage>[].obs;
  final pendingAction = Rxn<AssistantResponse>();
  final isLoading = false.obs;
  final error = RxnString();

  AssistantController({required this.service, required this.session});

  @override
  void onInit() {
    super.onInit();
    messages.add(_message(MessageRole.assistant, 'Hi ${session.displayName.split(' ').first}. I can help with your balances, transactions, cards, transfers, and support requests.'));
  }

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  ChatMessage _message(MessageRole role, String text, {ActionKind kind = ActionKind.none, ActionStatus status = ActionStatus.informational, Map<String, dynamic> payload = const {}}) => ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), role: role, text: text, createdAt: DateTime.now(), actionKind: kind, status: status, payload: payload);

  Future<void> send([String? suggested]) async {
    final text = (suggested ?? inputController.text).trim();
    if (text.isEmpty || isLoading.value) return;
    inputController.clear();
    error.value = null;
    pendingAction.value = null;
    messages.add(_message(MessageRole.user, text));
    isLoading.value = true;
    _scrollToEnd();
    try {
      final response = await service.respond(session, text);
      messages.add(_message(MessageRole.assistant, response.text, kind: response.actionKind, status: response.status, payload: response.payload));
      pendingAction.value = response.actionKind == ActionKind.none ? null : response;
    } on AuthorizationException catch (exception) {
      error.value = exception.message;
    } on ValidationException catch (exception) {
      error.value = exception.message;
    } catch (_) {
      error.value = 'I could not complete that request. Please try again.';
    } finally {
      isLoading.value = false;
      _scrollToEnd();
    }
  }

  Future<void> handleAction(ActionKind kind) async {
    if (kind == ActionKind.transferDraft) {
      final draft = await _showTransferReview();
      if (draft == null) return;
      try {
        final reference = await service.confirmTransfer(session, draft);
        pendingAction.value = null;
        messages.add(_message(MessageRole.assistant, 'Transfer completed securely. Your reference is $reference.', status: ActionStatus.completed));
      } catch (_) {
        error.value = 'The transfer was not completed. No money was moved.';
      }
      _scrollToEnd();
      return;
    }
    if (kind == ActionKind.freezeCard) {
      final confirmed = await _confirm('Freeze card?', 'New purchases will be declined while your card is frozen. You can unfreeze it later.');
      if (!confirmed) return;
      try {
        final reference = await service.confirmFreeze(session, true);
        pendingAction.value = null;
        messages.add(_message(MessageRole.assistant, 'Your card is now frozen. Reference: $reference', status: ActionStatus.completed));
      } catch (_) {
        error.value = 'The card was not frozen.';
      }
      return;
    }
    final category = await _showTicketCategory();
    if (category == null) return;
    try {
      final reference = await service.openTicket(session, category);
      pendingAction.value = null;
      messages.add(_message(MessageRole.assistant, 'Your request is open. Track it with reference $reference.', status: ActionStatus.completed));
    } catch (_) {
      error.value = 'I could not open the support request.';
    }
  }

  Future<TransferDraft?> _showTransferReview() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    return Get.bottomSheet<TransferDraft>(
      SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, Get.mediaQuery.viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Review transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('This is a draft. Secure confirmation is required before anything is sent.'),
        const SizedBox(height: 18),
        const _ReviewRow(label: 'From', value: 'Everyday checking  •••• 4821'),
        const _ReviewRow(label: 'To', value: 'My savings account'),
        TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ ')),
        const SizedBox(height: 10),
        TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.lock_outline), label: const Text('Review and securely confirm'), onPressed: () {
          final amount = double.tryParse(amountController.text.trim());
          if (amount == null || amount <= 0) { Get.snackbar('Invalid amount', 'Enter an amount greater than zero.'); return; }
          Get.back(result: TransferDraft(sourceAccountId: 'checking-001', destinationLabel: 'My savings account', amount: amount, date: DateTime.now(), note: noteController.text.trim()));
        })),
      ]))),
      isScrollControlled: true,
      backgroundColor: Get.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    );
  }

  Future<bool> _confirm(String title, String message) async => await Get.dialog<bool>(AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: Get.back, child: const Text('Cancel')), FilledButton.icon(onPressed: () => Get.back(result: true), icon: const Icon(Icons.fingerprint), label: const Text('Confirm securely'))])) ?? false;

  Future<String?> _showTicketCategory() => Get.bottomSheet<String>(SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ['Incorrect transaction', 'Card issue', 'Account issue'].map((category) => ListTile(title: Text(category), leading: const Icon(Icons.arrow_forward), onTap: () => Get.back(result: category))).toList())), backgroundColor: Get.theme.colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))));

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 78, child: Text(label, style: Theme.of(context).textTheme.labelMedium)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}