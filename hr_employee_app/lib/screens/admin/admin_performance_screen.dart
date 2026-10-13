import 'admin_edit_performance_screen.dart';
import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import 'admin_add_performance_screen.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';

class AdminPerformanceScreen extends StatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  State<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends State<AdminPerformanceScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  Future<void> deletePerformance(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Performance'),
          content: const Text('Are you sure you want to delete this record?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final response = await ApiService.delete('/admin/performance/$id');

      if (ApiService.isSuccess(response['status'])) {
        await getPerformance();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Performance deleted successfully')),
        );
      } else {
        if (!mounted) return;

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

  List<dynamic> performance = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getPerformance)
      ..start();
    getPerformance();
  }

  Future<void> getPerformance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/admin/performance');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
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
      if (mounted) {
        setState(() {
          if (!_hasLoaded) error = 'Something went wrong';
          loading = false;
          _hasLoaded = true;
        });
      }
    } finally {
      _requestInFlight = false;
    }
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
        title: const Text('Performance'),
        actions: const [LogoutAction()],
      ),

      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getPerformance)
          : performance.isEmpty
          ? const Center(child: Text('No performance records found'))
          : RefreshIndicator(
              onRefresh: getPerformance,
              child: ListView.builder(
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
                        child: Icon(Icons.assessment),
                      ),

                      title: Text(
                        user?['name'] ?? 'Unknown Employee',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      subtitle: Text(
                        'Employee ID: '
                        '${employee?['employee_id'] ?? '-'}\n'
                        'Review Date: '
                        '${record['review_date'] ?? '-'}\n'
                        'Rating: '
                        '${record['rating'] ?? '-'}\n'
                        'Comments: '
                        '${record['comments'] ?? '-'}',
                      ),

                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AdminEditPerformanceScreen(
                                      performance: Map<String, dynamic>.from(
                                        record,
                                      ),
                                    ),
                              ),
                            );

                            if (result == true) {
                              getPerformance();
                            }
                          }

                          if (value == 'delete') {
                            await deletePerformance(record['id']);
                          }
                        },

                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAddPerformanceScreen(),
            ),
          );

          if (result == true) {
            getPerformance();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
