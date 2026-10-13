import 'dart:async';

import 'package:flutter/widgets.dart';

/// Periodically refreshes the visible screen and refreshes it again on resume.
/// Covered routes are skipped, so a stack of open pages does not poll at once.
class AutoRefreshController with WidgetsBindingObserver {
  AutoRefreshController({
    required State<StatefulWidget> owner,
    required Future<void> Function() onRefresh,
    this.interval = const Duration(seconds: 20),
  }) : _owner = owner,
       _onRefresh = onRefresh;

  final State<StatefulWidget> _owner;
  final Future<void> Function() _onRefresh;
  final Duration interval;

  Timer? _timer;
  bool _refreshing = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => _refreshIfVisible());
  }

  void _refreshIfVisible() {
    if (!_owner.mounted || _refreshing) return;
    final route = ModalRoute.of(_owner.context);
    if (route != null && !route.isCurrent) return;

    _refreshing = true;
    unawaited(
      _onRefresh().catchError((Object _) {}).whenComplete(() {
        _refreshing = false;
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfVisible();
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
