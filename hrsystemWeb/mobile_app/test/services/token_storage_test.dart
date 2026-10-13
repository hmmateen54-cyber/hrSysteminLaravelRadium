import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> secureValues;

  setUp(() {
    secureValues = {};
    SharedPreferences.setMockInitialValues({'token': 'legacy-token'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
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
        .setMockMethodCallHandler(channel, null);
  });

  test('legacy tokens migrate out of SharedPreferences', () async {
    expect(await ApiService.getStoredToken(), 'legacy-token');
    expect(secureValues['token'], 'legacy-token');
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
  });
}
