import 'dart:io';

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/report_model.dart';
import '../../models/student_model.dart';
import '../../services/ai_service.dart';
import '../../widgets/status_badge.dart';
import 'package:file_picker/file_picker.dart';
import '../auth/login_screen.dart';
import 'submit_report.dart';
import 'report_detail.dart';
import '../../widgets/student_ocr_review_dialog.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final _db = DatabaseService();
  String _selectedReportFilter = 'active';

  // Settings fields
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSavingPassword = false;
  bool _isUploadingAvatar = false;
  String? _passwordError;
  String? _passwordSuccess;

  // Preset avatars matching Unsplash references
  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150', // Female
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150', // Male
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150', // Alternative Female
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150', // Alternative Male
  ];

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbUpdate);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbUpdate);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _onDbUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _manageCoGuardianAccess(List<StudentModel> children) async {
    if (children.isEmpty) return;
    final emailController = TextEditingController();
    var selectedChild = children.first;
    var loading = false;
    String? errorMessage;
    var guardiansFuture = _db.getChildGuardians(selectedChild.id);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Add another email'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add one other email address so a second parent can sign in to their own HayagSync account and access this child. The email must already be registered. A child can have up to 2 parent email addresses in total.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<StudentModel>(
                    initialValue: selectedChild,
                    decoration: const InputDecoration(
                      labelText: 'Child',
                      border: OutlineInputBorder(),
                    ),
                    items: children
                        .map(
                          (child) => DropdownMenuItem(
                            value: child,
                            child: Text('${child.name} (${child.section})'),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (child) {
                            if (child == null) return;
                            dialogSetState(() {
                              selectedChild = child;
                              guardiansFuture = _db.getChildGuardians(child.id);
                              errorMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: guardiansFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return const Text('Could not load shared accounts.');
                      }
                      final guardians = snapshot.data ?? [];
                      if (guardians.isEmpty) {
                        return const Text(
                          'No additional email has been added yet. You can add 1 more email address.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: guardians.map((guardian) {
                          final email = guardian['email']?.toString() ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              guardian['guardian_name']?.toString() ?? email,
                            ),
                            subtitle: Text(email),
                            trailing: IconButton(
                              tooltip: 'Remove access',
                              icon: const Icon(
                                Icons.person_remove_alt_1_outlined,
                              ),
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: dialogContext,
                                        builder: (confirmContext) => AlertDialog(
                                          title: const Text(
                                            'Remove shared access?',
                                          ),
                                          content: Text(
                                            '$email will no longer be able to view this child\'s reports.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                confirmContext,
                                                false,
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                confirmContext,
                                                true,
                                              ),
                                              child: const Text(
                                                'Remove access',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true) return;
                                      try {
                                        await _db.unlinkGuardianAccount(
                                          studentId: selectedChild.id,
                                          email: email,
                                        );
                                        dialogSetState(() {
                                          guardiansFuture = _db
                                              .getChildGuardians(
                                                selectedChild.id,
                                              );
                                        });
                                      } catch (e) {
                                        dialogSetState(
                                          () => errorMessage = e.toString(),
                                        );
                                      }
                                    },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Additional parent email',
                      hintText: 'parent@example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      dialogSetState(() {
                        loading = true;
                        errorMessage = null;
                      });
                      try {
                        final message = await _db.linkGuardianAccount(
                          studentId: selectedChild.id,
                          email: emailController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, message);
                        }
                      } catch (e) {
                        dialogSetState(
                          () => errorMessage = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          dialogSetState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add email'),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    if (result != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _handleLogout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;
    _db.logout();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<bool> _confirmStudentImage(File imageFile, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check enrollment form'),
        scrollable: true,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imageFile,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              const Text('This image will be scanned for the student details.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Scan form'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _changePassword(StateSetter dialogSetState) async {
    if (!_passwordFormKey.currentState!.validate()) return;
    dialogSetState(() {
      _isSavingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      await _db.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      dialogSetState(() {
        _passwordSuccess = "Password updated successfully.";
        _currentPasswordController.clear();
        _newPasswordController.clear();
      });
    } catch (e) {
      dialogSetState(() {
        _passwordError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      dialogSetState(() {
        _isSavingPassword = false;
      });
    }
  }

  void _changeAvatar(String url) async {
    await _db.updateProfilePicture(url);
    if (!mounted) return;
    Navigator.of(context).pop(); // Close avatar selector / settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated successfully.')),
    );
  }

  Future<void> _uploadAvatar(
    BuildContext dialogContext,
    StateSetter dialogSetState,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null ||
          result.files.isEmpty ||
          !mounted ||
          !dialogContext.mounted) {
        return;
      }

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) {
        throw Exception('Hindi mabuksan ang napiling larawan.');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw Exception('Hanggang 5 MB lang ang profile picture.');
      }

      final extension = file.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        throw Exception('Pumili ng JPG, PNG, GIF, o WebP na larawan.');
      }

      dialogSetState(() => _isUploadingAvatar = true);
      await _db.uploadProfilePicture(
        bytes: await File(filePath).readAsBytes(),
        fileName: file.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      if (dialogContext.mounted) {
        dialogSetState(() => _isUploadingAvatar = false);
        Navigator.of(dialogContext).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      if (dialogContext.mounted) {
        dialogSetState(() => _isUploadingAvatar = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showSettingsDialog() {
    final parent = _db.currentUser;
    if (parent == null) return;
    File? enrollmentForm;
    String? enrollmentFormName;
    var isScanningEnrollmentForm = false;

    // Reset password messages when opening settings
    _passwordError = null;
    _passwordSuccess = null;
    _currentPasswordController.clear();
    _newPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile & Settings',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar & Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: parent.avatarUrl != null
                              ? NetworkImage(parent.avatarUrl!)
                              : null,
                          backgroundColor: const Color(0xFF2563EB),
                          child: parent.avatarUrl == null
                              ? Text(
                                  parent.name.substring(0, 2).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parent.name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                parent.email,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: _isUploadingAvatar
                          ? null
                          : () => _uploadAvatar(context, dialogSetState),
                      icon: _isUploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_back_outlined),
                      label: Text(
                        _isUploadingAvatar
                            ? 'Uploading photo…'
                            : 'Upload profile picture',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Avatar Selection presets
                    const Text(
                      'Choose Preset Avatar',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _presetAvatars.map((url) {
                        final isSelected = parent.avatarUrl == url;
                        return InkWell(
                          onTap: () => _changeAvatar(url),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(url),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Student details helper card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LINKED CHILDREN',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (parent.students == null ||
                              parent.students!.isEmpty)
                            const Text(
                              'No children linked to your profile.',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            ...parent.students!.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Color(0xFF2563EB),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Last: ${s.lastName ?? '—'} · First: ${s.firstName ?? '—'} · MI: ${s.middleInitial ?? '—'}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            '${s.grade} - ${s.section} | AY: ${s.academicYear}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            'Student No.: ${s.lrn ?? '—'} | Gender: ${s.gender ?? '—'}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            'Parent/Guardian: ${s.parentFullName ?? parent.name}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: enrollmentForm == null
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF16A34A),
                          width: enrollmentForm == null ? 1 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.upload_file, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ADD CHILD',
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            enrollmentForm == null
                                ? 'Upload a clear Certificate of Matriculation (COM) to add a child.'
                                : 'COM uploaded. Ready to scan.',
                            style: TextStyle(
                              color: enrollmentForm == null
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF15803D),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (enrollmentForm != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    enrollmentFormName ?? 'Enrollment form',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove file',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: isScanningEnrollmentForm
                                      ? null
                                      : () => dialogSetState(() {
                                          enrollmentForm = null;
                                          enrollmentFormName = null;
                                        }),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          OutlinedButton.icon(
                            onPressed: isScanningEnrollmentForm
                                ? null
                                : () async {
                                    try {
                                      final result = await FilePicker.platform
                                          .pickFiles(type: FileType.image);
                                      if (result == null ||
                                          result.files.isEmpty ||
                                          !context.mounted) return;
                                      final file = result.files.first;
                                      final path = file.path;
                                      if (path == null) {
                                        throw Exception(
                                          'The selected image could not be opened.',
                                        );
                                      }
                                      dialogSetState(() {
                                        enrollmentForm = File(path);
                                        enrollmentFormName = file.name;
                                      });
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Upload failed: $e'),
                                      ));
                                    }
                                  },
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: Text(enrollmentForm == null
                                ? 'Add Child · Upload COM'
                                : 'Replace COM'),
                          ),
                          if (enrollmentForm != null) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: isScanningEnrollmentForm
                                  ? null
                                  : () async {
                                      final file = enrollmentForm!;
                                      dialogSetState(() {
                                        isScanningEnrollmentForm = true;
                                      });
                                      try {
                                        final ocrResult = await AIService()
                                            .scanEnrollmentCertificate(file.path);
                                        if (!ocrResult.success) {
                                          throw Exception(
                                            ocrResult.errorMessage ??
                                                'Failed to read enrollment document.',
                                          );
                                        }
                                        if (!mounted) return;
                                        final reviewed =
                                            await showStudentOcrReviewDialog(
                                          this.context,
                                          ocrResult,
                                        );
                                        if (!mounted || reviewed == null) return;
                                        await _db.addChild(
                                          studentName: reviewed.studentName!,
                                          sectionName: reviewed.studentSection!,
                                          gradeLevel: reviewed.studentGrade!,
                                          academicYear: reviewed.academicYear ?? '',
                                          studentNumber: reviewed.studentNumber!,
                                          firstName: reviewed.firstName!,
                                          lastName: reviewed.lastName!,
                                          middleInitial: reviewed.middleInitial!,
                                          gender: reviewed.gender!,
                                        );
                                        if (!mounted) return;
                                        Navigator.of(this.context).pop();
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                            'Child added successfully: ${reviewed.studentName}',
                                          ),
                                        ));
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(SnackBar(
                                          content: Text('Could not add child: $e'),
                                        ));
                                      } finally {
                                        if (context.mounted) {
                                          dialogSetState(() {
                                            isScanningEnrollmentForm = false;
                                          });
                                        }
                                      }
                                    },
                              icon: isScanningEnrollmentForm
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.document_scanner_outlined),
                              label: Text(isScanningEnrollmentForm
                                  ? 'Scanning COM…'
                                  : 'Scan COM'),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Password update form
                    const Text(
                      'Update Password',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_passwordSuccess != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: Text(
                                _passwordSuccess!,
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (_passwordError != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Text(
                                _passwordError!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: true,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                            ),
                            decoration: _dialogInputDecoration(
                              'Current Password',
                              Icons.lock_outline,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Enter current password'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                            ),
                            decoration: _dialogInputDecoration(
                              'New Password',
                              Icons.lock_open,
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? 'Must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isSavingPassword
                                ? null
                                : () => _changePassword(dialogSetState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSavingPassword
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildChildSelectorSection() {
    final parent = _db.currentUser;
    if (parent == null) return const SizedBox();
    final students = parent.students ?? [];

    if (students.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No children linked to your profile yet. Please add a child in Settings.',
                style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _showSettingsDialog,
              child: const Text(
                'Add Child',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final activeChild = _db.selectedChild;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.child_care, color: Color(0xFF2563EB), size: 24),
          const SizedBox(width: 12),
          const Text(
            'Selected Child:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StudentModel>(
                  value:
                      activeChild != null &&
                          students.any((s) => s.id == activeChild.id)
                      ? students.firstWhere((s) => s.id == activeChild.id)
                      : null,
                  hint: const Text(
                    'Select a child',
                    style: TextStyle(fontSize: 13),
                  ),
                  isExpanded: true,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  items: students.map((s) {
                    return DropdownMenuItem<StudentModel>(
                      value: s,
                      child: Text('${s.name} (${s.section})'),
                    );
                  }).toList(),
                  onChanged: (newChild) {
                    _db.selectChild(newChild);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = _db.currentUser;
    if (parent == null) return const SizedBox();

    final activeChild = _db.selectedChild;

    // Filter reports for selected child (both victim and alleged bully involvement)
    final allReports = _db.getReports().where((r) {
      if (activeChild == null) return false;
      final childName = activeChild.name.trim().toLowerCase();
      final isVictim = r.studentName.trim().toLowerCase() == childName;
      final isOffender =
          r.bullyName != null && r.bullyName!.trim().toLowerCase() == childName;
      return isVictim || isOffender;
    }).toList();

    final activeReports = allReports
        .where(
          (r) =>
              r.status.toLowerCase() != 'resolved' &&
              r.status.toLowerCase() != 'closed',
        )
        .toList();
    final resolvedReports = allReports
        .where(
          (r) =>
              r.status.toLowerCase() == 'resolved' ||
              r.status.toLowerCase() == 'closed',
        )
        .toList();
    final meetingsCount = allReports
        .where(
          (r) =>
              r.status.toLowerCase() == 'scheduled_meeting' ||
              r.status.toLowerCase() == 'scheduled',
        )
        .length;

    final currentList = switch (_selectedReportFilter) {
      'all' => allReports,
      'meetings' => allReports
          .where((r) =>
              r.status.toLowerCase() == 'scheduled_meeting' ||
              r.status.toLowerCase() == 'scheduled')
          .toList(),
      'resolved' => resolvedReports,
      _ => activeReports,
    };
    final currentListTitle = switch (_selectedReportFilter) {
      'all' => 'All Reports',
      'meetings' => 'Scheduled Meetings',
      'resolved' => 'Resolved Cases',
      _ => 'Active Cases',
    };
    final currentListEmptyMessage = switch (_selectedReportFilter) {
      'all' => 'No reports yet.',
      'meetings' => 'No scheduled meetings.',
      'resolved' => 'No resolved cases yet.',
      _ => 'No active reports.',
    };
    final currentListEmptyDescription = switch (_selectedReportFilter) {
      'all' => 'Submitted reports related to your child will appear here.',
      'meetings' => 'Scheduled meetings related to your child will appear here.',
      'resolved' => 'Resolved cases related to your child will appear here.',
      _ => 'Click "New Report" to submit a report.',
    };

    final double screenWidth = MediaQuery.of(context).size.width;
    final double childAspectRatio = screenWidth < 360
        ? 1.2
        : (screenWidth < 450 ? 1.5 : 1.9);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HAYAGSYNC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Parent Portal | ${parent.studentGrade}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: _showSettingsDialog,
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Sign Out',
              onPressed: _handleLogout,
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubmitReportScreen()),
            );
          },
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add_comment_outlined, size: 20),
          label: const Text(
            'New Report',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChildSelectorSection(),

                  // 4 Statistics Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _buildStatCard(
                        'Total Reports',
                        allReports.length,
                        const Color(0xFF1E293B),
                        Colors.white,
                        isSelected: _selectedReportFilter == 'all',
                        onTap: () => setState(() => _selectedReportFilter = 'all'),
                      ),
                      _buildStatCard(
                        'Active Cases',
                        activeReports.length,
                        const Color(0xFF2563EB),
                        const Color(0xFFEFF6FF),
                        isSelected: _selectedReportFilter == 'active',
                        onTap: () => setState(() => _selectedReportFilter = 'active'),
                      ),
                      _buildStatCard(
                        'Meetings Set',
                        meetingsCount,
                        const Color(0xFF7C3AED),
                        const Color(0xFFF5F3FF),
                        isSelected: _selectedReportFilter == 'meetings',
                        onTap: () => setState(() => _selectedReportFilter = 'meetings'),
                      ),
                      _buildStatCard(
                        'Resolved Cases',
                        resolvedReports.length,
                        const Color(0xFF16A34A),
                        const Color(0xFFF0FDF4),
                        isSelected: _selectedReportFilter == 'resolved',
                        onTap: () => setState(() => _selectedReportFilter = 'resolved'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 16),
                  Text(
                    currentListTitle,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildReportsList(
                    currentList,
                    emptyMessage: currentListEmptyMessage,
                    emptyDescription: currentListEmptyDescription,
                    isResolvedTab: _selectedReportFilter == 'resolved',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    int value,
    Color color,
    Color bg, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(
    List<ReportModel> reports, {
    required bool isResolvedTab,
    required String emptyMessage,
    required String emptyDescription,
  }) {
    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              isResolvedTab
                  ? Icons.verified_user_outlined
                  : Icons.inbox_outlined,
              size: 44,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptyDescription,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(reportId: report.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(
                builder: (context) {
                  final childName =
                      _db.selectedChild?.name.trim().toLowerCase() ?? '';
                  final isVictim =
                      report.studentName.trim().toLowerCase() == childName;
                  final isOffender =
                      report.bullyName != null &&
                      report.bullyName!.trim().toLowerCase() == childName;
                  final isAdviserReported =
                      report.reportSource == 'Adviser-Observed';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role & Status Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: report.status),
                          if (isOffender)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 12,
                                    color: Color(0xFFD97706),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Child Named as Alleged Offender (Inquiry)',
                                    style: TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isVictim)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Child Involved (Complainant / Subject)',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isAdviserReported)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Reported by Adviser',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        report.title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Victim: ${report.studentName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Bully: ${report.bullyName ?? "Not named"}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${report.category} · ${report.incidentLocation}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (report.evidenceVerificationState !=
                              'Unverified') ...[
                            Icon(
                              report.evidenceVerificationState == 'Verified'
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_outlined,
                              size: 13,
                              color:
                                  report.evidenceVerificationState == 'Verified'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              report.evidenceVerificationState == 'Verified'
                                  ? 'Evidence Checked'
                                  : 'AI Flagged',
                              style: TextStyle(
                                color:
                                    report.evidenceVerificationState ==
                                        'Verified'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
