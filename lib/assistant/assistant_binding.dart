import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'assistant_controller.dart';
import 'assistant_service.dart';
import 'banking_adapter.dart';
import 'models.dart';
import 'remote_assistant_service.dart';

const _useBackend = bool.fromEnvironment('USE_BACKEND', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment('ASSISTANT_API_BASE_URL', defaultValue: 'http://localhost:8000');

class AssistantBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AssistantUseCase>(() => _useBackend
        ? RemoteAssistantService(client: Dio(BaseOptions(baseUrl: _apiBaseUrl, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 12))))
        : AssistantService(adapter: MockBankingAdapter(), authorizer: const PolicyAuthorizer()));
    Get.lazyPut(() => AssistantController(
          service: Get.find<AssistantUseCase>(),
          session: const AuthenticatedSession(customerId: 'customer-demo-001', displayName: 'Ava Morgan', isAuthenticated: true),
        ));
  }
}