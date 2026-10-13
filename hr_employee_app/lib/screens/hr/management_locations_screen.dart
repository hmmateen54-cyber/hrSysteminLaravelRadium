import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';

class ManagementLocationsScreen extends StatefulWidget {
  const ManagementLocationsScreen({super.key});

  @override
  State<ManagementLocationsScreen> createState() =>
      _ManagementLocationsScreenState();
}

class _ManagementLocationsScreenState extends State<ManagementLocationsScreen> {
  List<Map<String, dynamic>> events = [];
  bool loading = true;
  String? error;

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiService.get('/management/location-events');
      if (!mounted) return;
      if (!ApiService.isSuccess(response['status'])) {
        setState(() {
          error = ApiService.messageFromResponse(
            response['data'],
            response['status'],
          );
          loading = false;
        });
        return;
      }
      final paginator = response['data'] is Map
          ? response['data']['events']
          : null;
      final rows = paginator is Map ? paginator['data'] : paginator;
      setState(() {
        events = rows is List
            ? rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to load location status.';
          loading = false;
        });
      }
    }
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Status'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          const LogoutAction(),
        ],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: load)
          : events.isEmpty
          ? const Center(child: Text('No location events have synchronized.'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.privacy_tip_outlined),
                      title: Text('Server-confirmed locations'),
                      subtitle: Text(
                        'Capture and confirmation times are shown. Precise coordinates are not displayed.',
                      ),
                    ),
                  ),
                  for (final event in events) _eventCard(event),
                ],
              ),
            ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final employee = event['employee'] is Map
        ? Map<String, dynamic>.from(event['employee'])
        : <String, dynamic>{};
    final user = employee['user'] is Map
        ? Map<String, dynamic>.from(employee['user'])
        : <String, dynamic>{};
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F5EF),
          child: Icon(Icons.location_on_outlined, color: Color(0xFF0B5D45)),
        ),
        title: Text(user['name']?.toString() ?? 'Employee'),
        subtitle: Text(
          'ID: ${employee['employee_id'] ?? '—'}\n'
          'Captured: ${_formatTime(event['recorded_at'])}\n'
          'Confirmed: ${_formatTime(event['synced_at'])}',
        ),
        isThreeLine: true,
        trailing: const Text(
          'RECORDED',
          style: TextStyle(
            color: Color(0xFF0B5D45),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
