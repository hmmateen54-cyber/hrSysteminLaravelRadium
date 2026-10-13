import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import 'hr_add_performance_screen.dart';
import 'hr_edit_performance_screen.dart';

class HRPerformanceScreen extends StatefulWidget {
  const HRPerformanceScreen({super.key});

  @override
  State<HRPerformanceScreen> createState() => _HRPerformanceScreenState();
}

class _HRPerformanceScreenState extends State<HRPerformanceScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  bool loading = true;
  String? error;

  List<dynamic> performance = [];

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(
      owner: this,
      onRefresh: loadPerformance,
    )..start();
    loadPerformance();
  }

  Future<void> loadPerformance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/hr/performance');

      if (!mounted) return;

      if (response['status'] == 200) {
        setState(() {
          performance = response['data']['performance'] ?? [];
          loading = false;
          error = null;
          _hasLoaded = true;
        });
      } else {
        setState(() {
          if (!_hasLoaded) {
            error = response['data']['message'] ?? 'Failed to load performance';
          }
          loading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (!_hasLoaded) error = 'Something went wrong';
        loading = false;
        _hasLoaded = true;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    super.dispose();
  }

  Future<void> deletePerformance(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Performance?'),
        content: const Text(
          'Are you sure you want to delete this performance record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiService.delete(
        '/hr/performance/${record['id']}',
      );

      if (!mounted) return;

      if (response['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Performance deleted successfully')),
        );

        await loadPerformance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['data']['message'] ?? 'Failed to delete performance',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Records'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadPerformance)
          : RefreshIndicator(
              onRefresh: loadPerformance,
              child: performance.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 250),
                        Center(child: Text('No performance records found')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: performance.length,
                      itemBuilder: (context, index) {
                        final record = performance[index];
                        final employee = record['employee'];
                        final user = employee?['user'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.star),
                            ),
                            title: Text(
                              user?['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Employee ID: '
                                '${employee?['employee_id'] ?? '-'}\n'
                                'Review Date: '
                                '${record['review_date'] ?? '-'}\n'
                                'Rating: '
                                '${record['rating'] ?? '-'} / 10\n'
                                'Comments: '
                                '${record['comments'] ?? '-'}',
                              ),
                            ),
                            isThreeLine: true,

                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  await deletePerformance(
                                    Map<String, dynamic>.from(record),
                                  );
                                } else if (value == 'edit') {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          HREditPerformanceScreen(
                                            record: Map<String, dynamic>.from(
                                              record,
                                            ),
                                          ),
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    await loadPerformance();
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HRAddPerformanceScreen(),
            ),
          );

          if (result == true && mounted) {
            await loadPerformance();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Review'),
      ),
    );
  }
}
