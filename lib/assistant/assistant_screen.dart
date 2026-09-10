import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'assistant_controller.dart';
import 'models.dart';

class AssistantScreen extends GetView<AssistantController> {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Digital banking assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text('Secure help for your everyday banking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: CircleAvatar(radius: 18, backgroundColor: colors.primaryContainer, child: Icon(Icons.shield_outlined, size: 19, color: colors.onPrimaryContainer)))],
      ),
      body: Obx(() => Column(children: [
        Expanded(child: ListView.builder(controller: controller.scrollController, padding: const EdgeInsets.fromLTRB(16, 20, 16, 12), itemCount: controller.messages.length + (controller.isLoading.value ? 1 : 0), itemBuilder: (context, index) => index == controller.messages.length ? const _TypingIndicator() : _MessageBubble(message: controller.messages[index]))),
        if (controller.pendingAction.value != null) _ActionPanel(response: controller.pendingAction.value!, onAction: controller.handleAction),
        _Suggestions(onSelected: controller.send),
        if (controller.error.value != null) _ErrorBanner(message: controller.error.value!, onRetry: controller.send),
        _Composer(controller: controller.inputController, onSend: controller.send, enabled: !controller.isLoading.value),
      ])),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});
  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(18).copyWith(bottomRight: isUser ? const Radius.circular(4) : null, bottomLeft: isUser ? null : const Radius.circular(4)),
          border: isUser ? null : Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: isUser ? colors.onPrimary : colors.onSurface, height: 1.4)),
            if (!isUser && message.payload['type'] == 'account_balance_card') ...[
              const SizedBox(height: 12),
              _AccountBalanceCards(payload: message.payload),
            ],
            if (!isUser && message.payload['type'] == 'transaction_list') ...[
              const SizedBox(height: 12),
              _TransactionList(payload: message.payload),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountBalanceCards extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _AccountBalanceCards({required this.payload});

  @override
  Widget build(BuildContext context) {
    final accounts = payload['data'] is Map<String, dynamic> ? (payload['data']['accounts'] as List<dynamic>? ?? const []) : (payload['accounts'] as List<dynamic>? ?? const []);
    return Column(
      children: accounts.map((item) {
        final account = item is Account ? item : null;
        final data = item is Map<String, dynamic> ? item : const <String, dynamic>{};
        final name = account?.name ?? data['name'] as String? ?? 'Account';
        final maskedNumber = account?.maskedNumber ?? data['masked_number'] as String? ?? 'Masked account';
        final currency = account?.currency ?? data['currency'] as String? ?? '';
        final available = account?.availableBalance ?? (data['available_balance'] as num?)?.toDouble() ?? 0;
        final balance = account?.balance ?? (data['balance'] as num?)?.toDouble() ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))), Text(maskedNumber, style: Theme.of(context).textTheme.labelMedium)]),
              const SizedBox(height: 8),
              Text('$currency ${available.toStringAsFixed(2)} available', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('$currency ${balance.toStringAsFixed(2)} current balance', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _TransactionList({required this.payload});

  @override
  Widget build(BuildContext context) {
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : payload;
    final transactions = data['transactions'] as List<dynamic>? ?? const [];
    return Column(
      children: transactions.map((item) {
        final transaction = item as Map<String, dynamic>;
        final isCredit = transaction['transaction_type'] == 'credit';
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(radius: 16, child: Icon(isCredit ? Icons.south_west : Icons.north_east, size: 16)),
          title: Text(transaction['merchant'] as String? ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(transaction['category'] as String? ?? 'Banking transaction'),
          trailing: Text('${isCredit ? '+' : '-'}${amount.toStringAsFixed(2)}', style: TextStyle(color: isCredit ? Colors.green.shade700 : null, fontWeight: FontWeight.w700)),
        );
      }).toList(),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _Suggestions({required this.onSelected});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: ['Show my balance', 'Recent transactions', 'Start a transfer', 'Freeze my card']
              .map((label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(label), onPressed: () => onSelected(label)),
                  ))
              .toList(),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;
  const _Composer({required this.controller, required this.onSend, required this.enabled});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: controller, enabled: enabled, minLines: 1, maxLines: 1, textInputAction: TextInputAction.send, onSubmitted: onSend, decoration: const InputDecoration(hintText: 'Ask about your banking'))), const SizedBox(width: 8), IconButton.filled(tooltip: 'Send message', onPressed: enabled ? () => onSend(controller.text) : null, icon: const Icon(Icons.arrow_upward))])));
}

class _ActionPanel extends StatelessWidget {
  final AssistantResponse response;
  final ValueChanged<ActionKind> onAction;
  const _ActionPanel({required this.response, required this.onAction});
  @override
  Widget build(BuildContext context) {
    final labels = {ActionKind.transferDraft: 'Review transfer', ActionKind.freezeCard: 'Freeze card securely', ActionKind.supportTicket: 'Open support request'};
    return Card(margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text(labels[response.actionKind] ?? 'Continue'), subtitle: const Text('Nothing is completed from chat alone.'), trailing: const Icon(Icons.chevron_right), onTap: () => onAction(response.actionKind)));
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 12, left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5)),
              SizedBox(width: 10),
              Text('Assistant is checking securely...'),
            ],
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(message), leading: const Icon(Icons.info_outline), actions: [TextButton(onPressed: onRetry, child: const Text('Retry'))]);
}