import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_button.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';

class HREditPerformanceScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const HREditPerformanceScreen({super.key, required this.record});

  @override
  State<HREditPerformanceScreen> createState() =>
      _HREditPerformanceScreenState();
}

class _HREditPerformanceScreenState extends State<HREditPerformanceScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController ratingController;
  late final TextEditingController commentsController;

  List<dynamic> employees = [];
  int? selectedEmployeeId;
  DateTime selectedDate = DateTime.now();

  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();

    ratingController = TextEditingController(
      text: widget.record['rating']?.toString() ?? '',
    );

    commentsController = TextEditingController(
      text: widget.record['comments']?.toString() ?? '',
    );

    final reviewDate = DateTime.tryParse(
      widget.record['review_date']?.toString() ?? '',
    );

    if (reviewDate != null) {
      selectedDate = reviewDate;
    }

    selectedEmployeeId = int.tryParse(
      widget.record['employee_id']?.toString() ??
          widget.record['employee']?['id']?.toString() ??
          '',
    );

    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      final response = await ApiService.get('/hr/employees');

      if (!mounted) return;

      if (response['status'] == 200) {
        setState(() {
          employees = response['data']['employees'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          error = response['data']['message'] ?? 'Failed to load employees';
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error = 'Failed to load employees';
        loading = false;
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

  Future<void> updatePerformance() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final date =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      final recordId = widget.record['id'];

      final response = await ApiService.patch('/hr/performance/$recordId', {
        'employee_id': selectedEmployeeId,
        'review_date': date,
        'rating': double.parse(ratingController.text),
        'comments': commentsController.text.trim(),
      });

      if (!mounted) return;

      if (response['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Performance updated successfully')),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['data']['message'] ?? 'Failed to update performance',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    } finally {
      if (mounted) {
        setState(() => saving = false);
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
        title: const Text('Edit Performance'),
        actions: const [LogoutAction()],
      ),
      body: loading
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
                        loading = true;
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
                      initialValue:
                          employees.any(
                            (employee) => employee['id'] == selectedEmployeeId,
                          )
                          ? selectedEmployeeId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        border: OutlineInputBorder(),
                      ),
                      items: employees.map((employee) {
                        final name = employee['user']?['name'] ?? 'Unknown';
                        final code = employee['employee_id'] ?? '-';

                        return DropdownMenuItem<int>(
                          value: employee['id'] as int,
                          child: Text(
                            '$name ($code)',
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
                        labelText: 'Comments',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      text: 'Update Performance',
                      loading: saving,
                      onPressed: updatePerformance,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
