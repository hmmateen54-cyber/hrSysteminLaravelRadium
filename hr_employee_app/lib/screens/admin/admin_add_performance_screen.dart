import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';

class AdminAddPerformanceScreen extends StatefulWidget {
  const AdminAddPerformanceScreen({super.key});

  @override
  State<AdminAddPerformanceScreen> createState() =>
      _AdminAddPerformanceScreenState();
}

class _AdminAddPerformanceScreenState extends State<AdminAddPerformanceScreen> {
  List<dynamic> employees = [];

  int? selectedEmployeeId;

  final reviewDateController = TextEditingController();
  final ratingController = TextEditingController();
  final commentsController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    getEmployees();
  }

  Future<void> getEmployees() async {
    try {
      final response = await ApiService.get('/admin/employees');

      if (ApiService.isSuccess(response['status'])) {
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
    } catch (e) {
      setState(() {
        error = 'Something went wrong';
        loading = false;
      });
    }
  }

  Future<void> savePerformance() async {
    if (selectedEmployeeId == null ||
        reviewDateController.text.isEmpty ||
        ratingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final response = await ApiService.post('/admin/performance', {
        'employee_id': selectedEmployeeId,
        'review_date': reviewDateController.text,
        'rating': ratingController.text,
        'comments': commentsController.text,
      });

      if (ApiService.isSuccess(response['status'])) {
        if (!mounted) return;

        Navigator.pop(context, true);
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['data']['message'] ??
                'Failed to create performance record',
          ),
        ),
      );
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
    reviewDateController.dispose();
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
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getEmployees)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: employees.map((employee) {
                      final user = employee['user'];

                      return DropdownMenuItem<int>(
                        value: employee['id'],
                        child: Text(
                          '${user?['name'] ?? 'Unknown'} '
                          '(${employee['employee_id'] ?? '-'})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEmployeeId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (date != null) {
                        reviewDateController.text =
                            '${date.year}-'
                            '${date.month.toString().padLeft(2, '0')}-'
                            '${date.day.toString().padLeft(2, '0')}';
                      }
                    },
                    child: AbsorbPointer(
                      child: AppTextField(
                        controller: reviewDateController,
                        label: 'Review Date',
                        hint: 'YYYY-MM-DD',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  AppTextField(
                    controller: ratingController,
                    label: 'Rating',
                    hint: '0 - 10',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  AppTextField(
                    controller: commentsController,
                    label: 'Comments',
                    maxLines: 4,
                  ),

                  const SizedBox(height: 24),

                  AppButton(
                    text: 'Save Performance',
                    onPressed: savePerformance,
                    loading: saving,
                  ),
                ],
              ),
            ),
    );
  }
}
