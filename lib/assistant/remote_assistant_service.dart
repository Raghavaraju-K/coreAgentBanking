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
  Future<String> confirmTransfer(AuthenticatedSession session, TransferDraft draft) => throw const AuthorizationException('Complete secure step-up authentication in the banking app before confirming a transfer.');

  @override
  Future<String> confirmFreeze(AuthenticatedSession session, bool freeze) => throw const AuthorizationException('Complete secure step-up authentication in the banking app before changing card status.');

  @override
  Future<String> openTicket(AuthenticatedSession session, String category) => throw const ValidationException('Support requests require the guided backend form.');

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