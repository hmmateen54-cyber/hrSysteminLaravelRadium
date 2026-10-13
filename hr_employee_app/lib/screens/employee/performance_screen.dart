import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';

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

  Future<void> getPerformance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/employee/performance');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
        setState(() {
          performance = response['data']['performance'];
          loading = false;
          error = null;
          _hasLoaded = true;
        });
      } else {
        setState(() {
          loading = false;
          if (!_hasLoaded) {
            error = response['data']['message'] ?? 'Failed to load performance';
          }
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          if (!_hasLoaded) error = 'Unable to connect to server';
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
                },
              ),
            ),
    );
  }
}
