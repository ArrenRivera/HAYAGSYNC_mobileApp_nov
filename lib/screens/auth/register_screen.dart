import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../widgets/student_ocr_review_dialog.dart';
import '../parent/parent_dashboard.dart';
import 'terms_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _parentNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<Map<String, String>> _verifiedChildren = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _agreeToTerms = false;
  String? _selectedCertificatePath;
  String? _selectedCertificateName;
  bool _isScanningCertificate = false;
  bool _certificateScanSucceeded = false;
  bool _certificateScanFailed = false;

  final _db = DatabaseService();
  final _ai = AIService();
  final _termsScrollController = ScrollController();

  @override
  void dispose() {
    _parentNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _termsScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificateFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final path = file.path;

        setState(() {
          _isLoading = true;
          _isScanningCertificate = true;
          _errorMessage = null;
          _selectedCertificatePath = path;
          _selectedCertificateName = name;
          _certificateScanSucceeded = false;
          _certificateScanFailed = false;
        });

        if (path == null) {
          throw Exception('The selected image could not be opened.');
        }
        final ocrResult = await _ai.scanEnrollmentCertificate(path);

        if (!ocrResult.success) {
          throw Exception(
            ocrResult.errorMessage ?? "Failed to verify enrollment document.",
          );
        }

        if (!mounted) return;
        final reviewed = await showStudentOcrReviewDialog(context, ocrResult);
        if (!mounted) return;
        if (reviewed == null) {
          setState(() {
            _isLoading = false;
            _isScanningCertificate = false;
          });
          return;
        }

        // Add to verified children list
        setState(() {
          _verifiedChildren.add({
            'studentName': reviewed.studentName!,
            'sectionName': reviewed.studentSection!,
            'gradeLevel': reviewed.studentGrade!,
            'academicYear': reviewed.academicYear ?? '',
            'certificateFilename': name,
            'studentNumber': reviewed.studentNumber!,
            'firstName': reviewed.firstName!,
            'lastName': reviewed.lastName!,
            'middleInitial': reviewed.middleInitial!,
            'gender': reviewed.gender!,
          });
          _isLoading = false;
          _isScanningCertificate = false;
          _certificateScanSucceeded = true;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Child confirmed: ${reviewed.studentName} (${reviewed.studentSection})',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isScanningCertificate = false;
        _certificateScanFailed = _selectedCertificatePath != null;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedChildren.isEmpty) {
      setState(() {
        _errorMessage =
            'Scan and verify a Certificate of Matriculation (COM) for at least one child before registering.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final first = _verifiedChildren.isEmpty
          ? <String, String>{}
          : _verifiedChildren.first;
      final childrenForRegistration = _verifiedChildren
          .map(
            (child) => {
              ...child,
              'parentFullName': _parentNameController.text.trim(),
            },
          )
          .toList();
      final newParent = await _db.registerParent(
        name: _parentNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        studentName: first['studentName'] ?? '',
        sectionName: first['sectionName'] ?? '',
        gradeLevel: first['gradeLevel'] ?? '',
        academicYear: first['academicYear'] ?? '',
        certificateFilename: first['certificateFilename'] ?? '',
        verifiedChildren: childrenForRegistration,
      );

      if (_db.currentUser == null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Check your email'),
            content: Text(
              'Your account has been created for ${newParent.email}. Confirm your email address before signing in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await TermsStorage.accept(newParent.id);

      if (!mounted) return;
      _showVerificationSuccessDialog(newParent);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationSuccessDialog(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 10),
              Text(
                'Enrollment Verified!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The OCR scanner successfully validated the Enrollment Certificate. Extracted Details:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildExtractedField('Student Name', user.studentName ?? ''),
              _buildExtractedField('Section/Grade', user.studentSection ?? ''),
              _buildExtractedField('Academic Year', user.academicYear ?? ''),
              _buildExtractedField('Status', 'ENROLLED', isStatus: true),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss Dialog
                Navigator.of(this.context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ParentDashboard()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Parent Dashboard'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExtractedField(
    String label,
    String value, {
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.white),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isStatus ? Colors.green : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comprehensive Terms & Conditions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ComprehensiveTermsWidget(
                    showDecline: false,
                    onAccept: () {
                      setState(() {
                        _agreeToTerms = true;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Parent Registration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Parent Account Setup',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload the student\'s enrollment form to register. The system will scan and verify the student details automatically using AI OCR.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                      ),
                    ),
                  ),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Full name
                          const Text(
                            'Parent / Guardian Full Name',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _parentNameController,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              'e.g. Juan Dela Cruz',
                              Icons.person_outline,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Please enter your full name'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Parent / Guardian Contact Number (Mobile or Landline)',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              '+63 912 345 6789 or (02) 8123 4567',
                              Icons.phone_outlined,
                            ),
                            validator: (value) {
                              final contact = value?.trim() ?? '';
                              if (contact.isEmpty) {
                                return 'Please enter a mobile or landline number.';
                              }
                              if (!RegExp(r'^[0-9+().\-\s]+$').hasMatch(contact)) {
                                return 'Enter a valid phone number.';
                              }
                              final digits = contact.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (digits.length < 7 || digits.length > 15) {
                                return 'Enter a number with 7 to 15 digits.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              'you@example.com',
                              Icons.email_outlined,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Please enter email'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              '••••••••',
                              Icons.lock_outline,
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 24),

                          // Verified Children List
                          if (_verifiedChildren.isNotEmpty) ...[
                            const Text(
                              'Verified Children',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._verifiedChildren.map(
                              (child) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF16A34A),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            child['studentName']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'Last: ${child['lastName']} · First: ${child['firstName']} · MI: ${child['middleInitial']}',
                                            style: const TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            '${child['gradeLevel']} - ${child['sectionName']}',
                                            style: const TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            'Student No.: ${child['studentNumber']} · Gender: ${child['gender']}',
                                            style: const TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            'Parent/Guardian: ${_parentNameController.text.trim().isEmpty ? 'Use the name above' : _parentNameController.text.trim()}',
                                            style: const TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFEF4444),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _verifiedChildren.remove(child);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Certificate Upload Header
                          const Text(
                            'Certificate of Matriculation (COM) (Required)',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload and scan a clear Certificate of Matriculation (COM) for at least one child to create your account. You may add additional children later.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),

                          InkWell(
                            onTap: _isLoading
                                ? null
                                : _pickCertificateFromDevice,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _certificateScanSucceeded
                                    ? const Color(0xFFF0FDF4)
                                    : _certificateScanFailed
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _certificateScanSucceeded
                                      ? const Color(0xFF22C55E)
                                      : _certificateScanFailed
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFCBD5E1),
                                  width: _certificateScanSucceeded ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (_selectedCertificatePath != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(_selectedCertificatePath!),
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox(
                                              height: 100,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                size: 36,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                      ),
                                    )
                                  else
                                    const SizedBox(
                                      height: 100,
                                      child: Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 38,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        _certificateScanSucceeded
                                            ? Icons.check_circle
                                            : _certificateScanFailed
                                            ? Icons.error_outline
                                            : Icons.upload_file_outlined,
                                        color: _certificateScanSucceeded
                                            ? const Color(0xFF16A34A)
                                            : _certificateScanFailed
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedCertificateName ??
                                                  'Upload Certificate of Matriculation (COM)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    _selectedCertificatePath ==
                                                        null
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFF166534),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              _isScanningCertificate
                                                  ? 'Scanning the certificate with OCR…'
                                                  : _certificateScanSucceeded
                                                  ? 'Scan complete · Ready to register'
                                                  : _certificateScanFailed
                                                  ? 'Some fields could not be read · review the message above'
                                                  : _selectedCertificatePath ==
                                                        null
                                                  ? 'Select a COM image to begin scanning'
                                                  : 'File selected · Tap to scan again',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Clickable T&C Card inside register form
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _agreeToTerms,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged:
                                          null, // Disabled: must click the terms link to accept
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: _showTermsDialog,
                                        child: RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 12,
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    'I have read and agree to the ',
                                              ),
                                              TextSpan(
                                                text:
                                                    'Comprehensive Terms & Conditions.',
                                                style: TextStyle(
                                                  color: Color(0xFF2563EB),
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: (_isLoading || !_agreeToTerms)
                                ? null
                                : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('AI OCR Scanning Certificate...'),
                                    ],
                                  )
                                : const Text(
                                    'Register & Verify Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
