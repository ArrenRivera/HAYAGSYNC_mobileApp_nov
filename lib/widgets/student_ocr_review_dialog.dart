import 'package:flutter/material.dart';

import '../services/ai_service.dart';

Future<OCRResult?> showStudentOcrReviewDialog(
  BuildContext context,
  OCRResult scan,
) {
  return showDialog<OCRResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StudentOcrReviewDialog(scan: scan),
  );
}

class _StudentOcrReviewDialog extends StatefulWidget {
  const _StudentOcrReviewDialog({required this.scan});

  final OCRResult scan;

  @override
  State<_StudentOcrReviewDialog> createState() =>
      _StudentOcrReviewDialogState();
}

class _StudentOcrReviewDialogState extends State<_StudentOcrReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _middle;
  late final TextEditingController _grade;
  late final TextEditingController _section;
  late final TextEditingController _gender;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.scan.studentNumber ?? '');
    _first = TextEditingController(text: widget.scan.firstName ?? '');
    _last = TextEditingController(text: widget.scan.lastName ?? '');
    _middle = TextEditingController(text: widget.scan.middleInitial ?? '');
    _grade = TextEditingController(text: widget.scan.studentGrade ?? '');
    _section = TextEditingController(text: widget.scan.studentSection ?? '');
    _gender = TextEditingController(text: widget.scan.gender ?? '');
  }

  @override
  void dispose() {
    _number.dispose();
    _first.dispose();
    _last.dispose();
    _middle.dispose();
    _grade.dispose();
    _section.dispose();
    _gender.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final middleInitial = _middle.text.trim().replaceAll('.', '');
    final gradeNumber = RegExp(r'\d+').firstMatch(_grade.text)?.group(0);
    final normalizedGrade = gradeNumber == null
        ? _grade.text.trim()
        : 'Grade $gradeNumber';
    Navigator.of(context).pop(
      OCRResult(
        success: true,
        studentNumber: _number.text.trim(),
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        middleInitial: middleInitial,
        studentName:
            '${_last.text.trim()}, ${_first.text.trim()} $middleInitial.',
        studentGrade: normalizedGrade,
        studentSection: _section.text.trim(),
        gender: _gender.text.trim(),
        academicYear: widget.scan.academicYear ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review scanned student details'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'OCR results are a draft. Check each field and correct anything it read incorrectly.',
              ),
              const SizedBox(height: 14),
              _requiredField(_number, 'Student number'),
              _requiredField(_first, 'First name'),
              _requiredField(_last, 'Last name'),
              _requiredField(_middle, 'Middle initial'),
              _requiredField(_grade, 'Grade'),
              _requiredField(_section, 'Section'),
              _requiredField(_gender, 'Gender'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirm details')),
      ],
    );
  }

  Widget _requiredField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }
}
