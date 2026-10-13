# hr_employee_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## API configuration

The app uses `HR_API_BASE_URL` as a build-time Dart define. It defaults to the
current LAN development server. Point debug and release builds at the intended
server with a URL ending in `/api` and no trailing slash, for example:

```shell
flutter run --dart-define=HR_API_BASE_URL=https://hr.example.com/api
flutter build apk --release --dart-define=HR_API_BASE_URL=https://hr.example.com/api
```

Android permits cleartext HTTP only for debug builds. Release builds require an
HTTPS API URL.
