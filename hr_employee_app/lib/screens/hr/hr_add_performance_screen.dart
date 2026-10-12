import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_button.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';

class HRAddPerformanceScreen extends StatefulWidget {
  const HRAddPerformanceScreen({super.key});

  @override
  State<HRAddPerformanceScreen> createState() => _HRAddPerformanceScreenState();
}

class _HRAddPerformanceScreenState extends State<HRAddPerformanceScreen> {
  final formKey = GlobalKey<FormState>();

  final ratingController = TextEditingController();
  final commentsController = TextEditingController();

  List<dynamic> employees = [];
  int? selectedEmployeeId;
  DateTime selectedDate = DateTime.now();

  bool loadingEmployees = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      final response = await ApiService.get('/hr/employees');

      if (!mounted) return;

      if (response['status'] == 200) {
        setState(() {
          employees = response['data']['employees'] ?? [];
          loadingEmployees = false;
        });
      } else {
        setState(() {
          error = response['data']['message'] ?? 'Failed to load employees';
          loadingEmployees = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Failed to load employees';
        loadingEmployees = false;
      });
    }
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> savePerformance() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final date =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      final response = await ApiService.post('/hr/performance', {
        'employee_id': selectedEmployeeId,
        'review_date': date,
        'rating': double.parse(ratingController.text),
        'comments': commentsController.text.trim(),
      });

      if (!mounted) return;

      if (response['status'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Performance record added successfully'),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['data']['message'] ?? 'Failed to save performance',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ratingController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Performance'),
        actions: const [LogoutAction()],
      ),
      body: loadingEmployees
          ? const AppLoader()
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        loadingEmployees = true;
                        error = null;
                      });
                      loadEmployees();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : employees.isEmpty
          ? const Center(child: Text('No employees found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedEmployeeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Employee',
                        border: OutlineInputBorder(),
                      ),
                      items: employees.map((employee) {
                        final user = employee['user'];
                        final name = user?['name'] ?? 'Unknown';
                        final employeeCode = employee['employee_id'] ?? '-';

                        return DropdownMenuItem<int>(
                          value: employee['id'],
                          child: Text(
                            '$name ($employeeCode)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedEmployeeId = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Select an employee' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Review Date',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        '${selectedDate.day}/'
                        '${selectedDate.month}/'
                        '${selectedDate.year}',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: ratingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rating (0–10)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final rating = double.tryParse(value ?? '');

                        if (rating == null || rating < 0 || rating > 10) {
                          return 'Enter a rating from 0 to 10';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: commentsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Comments (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      text: 'Save Performance',
                      loading: saving,
                      onPressed: savePerformance,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
