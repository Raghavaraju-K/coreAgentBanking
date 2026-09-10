import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'assistant_service.dart';
import 'models.dart';

class RemoteAssistantService implements AssistantUseCase {
  final Dio client;
  final FlutterSecureStorage secureStorage;

  const RemoteAssistantService({required this.client, this.secureStorage = const FlutterSecureStorage()});

  @override
  Future<AssistantResponse> respond(AuthenticatedSession session, String input) async {
    final token = await secureStorage.read(key: 'access_token') ?? 'demo-token';
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/api/v1/assistant/messages',
        data: {
          'message': input,
          'context': {'locale': 'en-IN', 'timezone': 'Asia/Kolkata'},
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? const <String, dynamic>{};
      final intent = data['intent'] as String?;
      final uiPayload = data['ui_payload'] as Map<String, dynamic>?;
      return AssistantResponse(
        text: data['assistant_message'] as String? ?? 'I could not understand that request.',
        actionKind: _actionKind(intent),
        status: _actionStatus(data['state'] as String?),
        metadata: {'uiPayloadType': uiPayload?['type'] as String? ?? 'text'},
        payload: uiPayload ?? const {},
      );
    } on DioException catch (exception) {
      final statusCode = exception.response?.statusCode;
      if (statusCode == 401) throw const AuthorizationException('Your session has expired. Please sign in again.');
      if (exception.type == DioExceptionType.connectionError || exception.type == DioExceptionType.connectionTimeout) {
        throw const ValidationException('Cannot reach the banking API. Start FastAPI on port 8000 and try again.');
      }
      throw const ValidationException('The banking service is unavailable. Please try again.');
    }
  }

  @override
  Future<String> confirmTransfer(AuthenticatedSession session, TransferDraft draft) async {
    final response = await client.post<Map<String, dynamic>>('/api/v1/transfers/draft', data: {
      'source_account_id': draft.sourceAccountId,
      'destination_account_id': 'savings-001',
      'amount': draft.amount,
      'scheduled_date': draft.date.toIso8601String().substring(0, 10),
      'note': draft.note,
    }, options: await _authOptions());
    final transferId = response.data?['id'] as String?;
    if (transferId == null) throw const ValidationException('The transfer draft could not be created.');
    final receipt = await client.post<Map<String, dynamic>>('/api/v1/transfers/$transferId/confirm', data: {'idempotency_key': _idempotencyKey(), 'step_up_token': await _stepUpToken()}, options: await _authOptions());
    return receipt.data?['reference_id'] as String? ?? 'completed';
  }

  @override
  Future<String> confirmFreeze(AuthenticatedSession session, bool freeze) async {
    final endpoint = freeze ? 'freeze' : 'unfreeze';
    final response = await client.post<Map<String, dynamic>>('/api/v1/cards/checking-001/$endpoint', data: {'idempotency_key': _idempotencyKey(), 'step_up_token': await _stepUpToken()}, options: await _authOptions());
    return response.data?['status'] as String? ?? 'completed';
  }

  @override
  Future<String> openTicket(AuthenticatedSession session, String category) async {
    final normalized = category.toLowerCase().contains('card') ? 'card_issue' : category.toLowerCase().contains('account') ? 'account_issue' : 'incorrect_transaction';
    final response = await client.post<Map<String, dynamic>>('/api/v1/support/tickets', data: {'category': normalized, 'description': category}, options: await _authOptions());
    return response.data?['reference'] as String? ?? 'opened';
  }

  Future<Options> _authOptions() async {
    final token = await secureStorage.read(key: 'access_token') ?? 'demo-token';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<String> _stepUpToken() async {
    final response = await client.post<Map<String, dynamic>>('/api/v1/assistant/actions/00000000-0000-4000-8000-000000000001/step-up/verify', data: {'method': 'biometric'}, options: await _authOptions());
    return response.data?['step_up_token'] as String? ?? (throw const AuthorizationException('Secure confirmation was not completed.'));
  }

  String _idempotencyKey() => 'assistant-${DateTime.now().microsecondsSinceEpoch}';

  ActionKind _actionKind(String? intent) {
    switch (intent) {
      case 'internal_transfer': return ActionKind.transferDraft;
      case 'card_freeze': return ActionKind.freezeCard;
      case 'support_ticket': return ActionKind.supportTicket;
      default: return ActionKind.none;
    }
  }

  ActionStatus _actionStatus(String? state) {
    switch (state) {
      case 'draft': return ActionStatus.draft;
      case 'requires_confirmation':
      case 'requires_step_up': return ActionStatus.draft;
      case 'completed': return ActionStatus.completed;
      case 'failed': return ActionStatus.failed;
      default: return ActionStatus.informational;
    }
  }
}