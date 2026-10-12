import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';

class AdminEditPerformanceScreen extends StatefulWidget {
  final Map<String, dynamic> performance;

  const AdminEditPerformanceScreen({super.key, required this.performance});

  @override
  State<AdminEditPerformanceScreen> createState() =>
      _AdminEditPerformanceScreenState();
}

class _AdminEditPerformanceScreenState
    extends State<AdminEditPerformanceScreen> {
  final reviewDateController = TextEditingController();
  final ratingController = TextEditingController();
  final commentsController = TextEditingController();

  int? selectedEmployeeId;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    selectedEmployeeId = widget.performance['employee_id'];

    reviewDateController.text = widget.performance['review_date'] ?? '';

    ratingController.text = widget.performance['rating']?.toString() ?? '';

    commentsController.text = widget.performance['comments'] ?? '';
  }

  Future<void> updatePerformance() async {
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
      final id = widget.performance['id'];

      final response = await ApiService.patch('/admin/performance/$id', {
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
            response['data']['message'] ?? 'Failed to update performance',
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
        title: const Text('Edit Performance'),
        actions: const [LogoutAction()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Employee ID: '
              '${widget.performance['employee_id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(reviewDateController.text) ??
                      DateTime.now(),
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
                ),
              ),
            ),

            const SizedBox(height: 16),

            AppTextField(
              controller: ratingController,
              label: 'Rating',
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
              text: 'Update Performance',
              onPressed: updatePerformance,
              loading: saving,
            ),
          ],
        ),
      ),
    );
  }
}
