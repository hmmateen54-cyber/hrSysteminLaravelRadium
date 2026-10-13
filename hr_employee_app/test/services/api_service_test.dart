import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/services/api_service.dart';

void main() {
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
}
