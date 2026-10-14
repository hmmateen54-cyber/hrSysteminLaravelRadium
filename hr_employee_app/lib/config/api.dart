class Api {
  static const String baseUrl = String.fromEnvironment(
    'HR_API_BASE_URL',
    defaultValue: 'http://192.168.18.164:8000/api',
  );
}
