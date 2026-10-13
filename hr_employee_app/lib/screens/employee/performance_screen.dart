import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/offline_cache_banner.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../services/offline_sync_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  List<dynamic> performance = [];
  bool loading = true;
  String? error;
  String? _cacheFetchedAt;
  bool _hasCachedData = false;
  bool _offlineMode = false;

  Future<void> getPerformance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final cached = await OfflineSyncService.readCachedItems('performance');
      if (cached != null && mounted) {
        setState(() {
          performance = (cached['items'] as List?) ?? [];
          _cacheFetchedAt = cached['fetched_at']?.toString();
          _hasCachedData = true;
          loading = false;
          _hasLoaded = true;
        });
      }
    } catch (_) {
      // Try the server even if the local cache is unavailable.
    }

    try {
      final response = await ApiService.get('/employee/performance');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];
        final rows = data is Map ? data['performance'] : null;
        final remote = rows is List
            ? rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];
        try {
          await OfflineSyncService.saveCachedItems('performance', remote);
          final saved = await OfflineSyncService.readCachedItems('performance');
          _cacheFetchedAt = saved?['fetched_at']?.toString();
          _hasCachedData = true;
        } catch (_) {
          // Continue with the server response if local storage is unavailable.
        }
        setState(() {
          performance = remote;
          loading = false;
          error = null;
          _offlineMode = false;
          _hasLoaded = true;
        });
      } else {
        setState(() {
          loading = false;
          _offlineMode =
              _hasCachedData &&
              (response['status'] == 429 ||
                  (response['status'] is int && response['status'] >= 500));
          if (!_hasLoaded || !_offlineMode) {
            error = response['data']['message'] ?? 'Failed to load performance';
          }
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _offlineMode = _hasCachedData;
          if (!_hasLoaded || !_offlineMode) {
            error = 'Unable to connect to server';
          }
          _hasLoaded = true;
        });
      }
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();

    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getPerformance)
      ..start();
    getPerformance();
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Performance'),
        actions: const [LogoutAction()],
      ),

      body: loading
          ? const AppLoader()
          : error != null && !_offlineMode
          ? AppError(message: error!, onRetry: getPerformance)
          : RefreshIndicator(
              onRefresh: getPerformance,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_offlineMode)
                    OfflineCacheBanner(
                      fetchedAt: _cacheFetchedAt,
                      onRetry: getPerformance,
                    ),
                  if (performance.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 130),
                      child: Center(
                        child: Text('No performance records found'),
                      ),
                    ),
                  ...List.generate(performance.length, (index) {
                    final record = performance[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.assessment),
                        ),

                        title: Text(
                          'Rating: ${record['rating']}/5',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        subtitle: Text(
                          'Review Date: ${record['review_date']}\n'
                          '${record['comments'] ?? 'No comments'}',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
