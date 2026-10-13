import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_section_header.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const AppSectionHeader(
                    title: 'Performance history',
                    subtitle: 'Reviews and feedback shared with your account',
                  ),
                  if (_offlineMode)
                    OfflineCacheBanner(
                      fetchedAt: _cacheFetchedAt,
                      onRetry: getPerformance,
                    ),
                  if (performance.isEmpty)
                    const AppEmptyState(
                      icon: Icons.insights_outlined,
                      title: 'No reviews available',
                      description:
                          'Performance reviews will appear here when they are shared with you.',
                    ),
                  ...List.generate(performance.length, (index) {
                    final record = performance[index];
                    final rating = record['rating']?.toString();
                    final comments = record['comments']?.toString().trim();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.insights_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Performance review',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        record['review_date']?.toString() ??
                                            'Date unavailable',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (rating != null)
                                  Text(
                                    '$rating / 5',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                              ],
                            ),
                            if (comments != null && comments.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              Text(
                                comments,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
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
