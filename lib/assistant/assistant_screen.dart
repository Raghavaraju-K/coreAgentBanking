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
        if (controller.messages.length == 1) _Suggestions(onSelected: controller.send),
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
    return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 560), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), decoration: BoxDecoration(color: isUser ? colors.primary : colors.surface, borderRadius: BorderRadius.circular(18).copyWith(bottomRight: isUser ? const Radius.circular(4) : null, bottomLeft: isUser ? null : const Radius.circular(4)), border: isUser ? null : Border.all(color: colors.outlineVariant)), child: Text(message.text, style: TextStyle(color: isUser ? colors.onPrimary : colors.onSurface, height: 1.4))));
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
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: controller, enabled: enabled, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: onSend, decoration: const InputDecoration(hintText: 'Ask about your banking'))), const SizedBox(width: 8), IconButton.filled(tooltip: 'Send message', onPressed: enabled ? () => onSend(controller.text) : null, icon: const Icon(Icons.arrow_upward))])));
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