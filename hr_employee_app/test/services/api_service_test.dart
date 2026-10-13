import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late Map<String, String> secureValues;

  setUp(() {
    secureValues = {};
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          switch (call.method) {
            case 'read':
              return secureValues[arguments['key']];
            case 'write':
              secureValues[arguments['key'] as String] =
                  arguments['value'] as String;
              return null;
            case 'delete':
              secureValues.remove(arguments['key']);
              return null;
            default:
              throw PlatformException(code: 'unsupported_method');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'pending profile responses keep their server message and are not 401s',
    () {
      final response = {'message': ApiService.pendingProfileMessage};

      expect(ApiService.isPendingProfileResponse(response), isTrue);
      expect(ApiService.isUnauthorized(403), isFalse);
      expect(
        ApiService.messageFromResponse(response, 403),
        ApiService.pendingProfileMessage,
      );
    },
  );

  test('legacy preference tokens migrate to secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'token': 'legacy-token',
      'user': '{"id":4}',
    });

    expect(await ApiService.getStoredToken(), 'legacy-token');

    final preferences = await SharedPreferences.getInstance();
    expect(secureValues['token'], 'legacy-token');
    expect(preferences.getString('token'), isNull);
    expect(preferences.getString('user'), '{"id":4}');
  });

  test(
    'new tokens are stored securely and logout clears session data',
    () async {
      SharedPreferences.setMockInitialValues({'user': '{"id":4}'});

      await ApiService.storeToken('new-token');
      expect(secureValues['token'], 'new-token');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('token'), isNull);
      await ApiService.clearSession();
      expect(secureValues, isEmpty);
      expect(preferences.getString('user'), isNull);
    },
  );
}
