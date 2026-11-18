import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';

class AnonymousReportScreen extends StatefulWidget {
  const AnonymousReportScreen({super.key});

  @override
  State<AnonymousReportScreen> createState() => _AnonymousReportScreenState();
}

class _AnonymousReportScreenState extends State<AnonymousReportScreen> {
  static const int _maxEvidenceFiles = 5;
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const int _maxVideoBytes = 20 * 1024 * 1024;
  static const int _maxTotalEvidenceBytes = 50 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _otherLocationController = TextEditingController();
  final _victimNameController = TextEditingController();
  final _victimSectionController = TextEditingController();
  final _bullyNameController = TextEditingController();
  final _bullyGradeController = TextEditingController();
  final _witnessesController = TextEditingController();
  final List<PlatformFile> _selectedEvidenceFiles = [];

  String _selectedCategory = 'Physical';
  String _selectedUrgency = 'Moderate';
  String _selectedVictimGrade = 'Grade 7';
  String _selectedLocation = 'Classroom';
  DateTime _incidentDate = DateTime.now();
  TimeOfDay _incidentTime = TimeOfDay.now();

  bool _isSubmitting = false;

  final List<String> _categories = [
    'Physical',
    'Verbal',
    'Cyberbullying',
    'Social / Relational Exclusion',
    'Extortion & Coercion',
    'Harassment & Intimidation',
    'Property Damage & Vandalism',
    'Other / Unspecified',
  ];

  final List<String> _gradeLevels = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
    'Unknown / Not Sure',
  ];

  final List<String> _urgencyLevels = ['Low', 'Moderate', 'High', 'Critical'];

  final List<String> _commonLocations = [
    'Classroom',
    'Hallway / Corridors',
    'School Canteen / Cafeteria',
    'Gymnasium / Sports Complex',
    'Senior High Study Hub / Library',
    'School Gate / Campus Perimeter',
    'Restroom / Comfort Rooms',
    'Online / Social Media Platform',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = _commonLocations.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _otherLocationController.dispose();
    _victimNameController.dispose();
    _victimSectionController.dispose();
    _bullyNameController.dispose();
    _bullyGradeController.dispose();
    _witnessesController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidenceFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'mp4',
        'mov',
        'webm',
        '3gp',
      ],
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final accepted = <PlatformFile>[];
    var acceptedBytes = 0;
    for (final file in result.files.take(_maxEvidenceFiles)) {
      final extension = file.extension?.toLowerCase() ?? '';
      final isImage = {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension);
      final isVideo = {'mp4', 'mov', 'webm', '3gp'}.contains(extension);
      final maxBytes = isImage
          ? _maxImageBytes
          : (isVideo ? _maxVideoBytes : 0);
      if (maxBytes == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${file.name}: unsupported file type.')),
        );
      } else if (file.size > maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${file.name} exceeds the ${maxBytes ~/ (1024 * 1024)} MB limit.',
            ),
          ),
        );
      } else if (acceptedBytes + file.size > _maxTotalEvidenceBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} would exceed the 50 MB total limit.'),
          ),
        );
      } else {
        accepted.add(file);
        acceptedBytes += file.size;
      }
    }
    if (result.files.length > _maxEvidenceFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 5 evidence files.')),
      );
    }
    setState(() {
      _selectedEvidenceFiles
        ..clear()
        ..addAll(accepted);
    });
  }

  String? _evidenceContentType(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case '3gp':
        return 'video/3gpp';
      default:
        return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _incidentDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _incidentTime,
    );
    if (picked != null) {
      setState(() => _incidentTime = picked);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final combinedDateTime = DateTime(
        _incidentDate.year,
        _incidentDate.month,
        _incidentDate.day,
        _incidentTime.hour,
        _incidentTime.minute,
      );

      final witnessesList = _witnessesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final file in _selectedEvidenceFiles) {
        final ext = file.extension?.toLowerCase() ?? '';
        if (!{'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)) continue;
        final path = file.path;
        if (path == null) {
          throw Exception('${file.name} could not be screened.');
        }
        final screening = await AIService().screenEvidencePhoto(path, file.name);
        if (screening.rejected) throw Exception(screening.details);
      }

      final evidencePaths = <String>[];
      for (final file in _selectedEvidenceFiles) {
        final ext = file.extension?.toLowerCase() ?? '';
        final perFileLimit = {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)
            ? _maxImageBytes
            : _maxVideoBytes;
        if (file.size > perFileLimit) {
          throw Exception('${file.name} is larger than its upload limit.');
        }
        final path = file.path;
        final contentType = _evidenceContentType(file.name);
        if (path == null || contentType == null) {
          throw Exception(
            'Could not read ${file.name}. Please select it again.',
          );
        }
        final objectPath = await _db.uploadAnonymousEvidence(
          bytes: await File(path).readAsBytes(),
          fileName: file.name,
          contentType: contentType,
        );
        evidencePaths.add(objectPath);
      }

      final report = await _db.submitAnonymousReport(
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Anonymous Report: $_selectedCategory Bullying',
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        incidentDate: combinedDateTime,
        incidentLocation:
            _selectedLocation == 'Other' &&
                _otherLocationController.text.trim().isNotEmpty
            ? _otherLocationController.text.trim()
            : _selectedLocation,
        victimName: _victimNameController.text.trim().isNotEmpty
            ? _victimNameController.text.trim()
            : null,
        victimGrade: _selectedVictimGrade != 'Unknown / Not Sure'
            ? _selectedVictimGrade
            : null,
        victimSection: _victimSectionController.text.trim().isNotEmpty
            ? _victimSectionController.text.trim()
            : null,
        bullyName: _bullyNameController.text.trim().isNotEmpty
            ? _bullyNameController.text.trim()
            : null,
        bullyGradeSection: _bullyGradeController.text.trim().isNotEmpty
            ? _bullyGradeController.text.trim()
            : null,
        witnesses: witnessesList.isNotEmpty ? witnessesList : null,
        urgencyLevel: _selectedUrgency,
        evidenceUrl: evidencePaths.isNotEmpty ? evidencePaths.join(',') : null,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF16A34A),
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anonymous Report Submitted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thank you for reporting. Your report has been submitted safely and 100% anonymously.',
                style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Case Reference ID: #${report.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Workflow Status: Stage 1 — OSD Initial Assessment',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All authorized campus authorities (OSD, Ministrong Tagasubaybay, Advisers, and Principal) have been notified for coordinated action.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Return to Sign In'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Anonymous Incident Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Anonymity Guarantee Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.security,
                          color: Color(0xFF2563EB),
                          size: 26,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confidential & Safe Anonymous Reporting',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You do not need an account. Your identity, personal contact details, IP address, and device information are completely protected and never recorded.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E40AF),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 1: Incident Specifics
                  _buildSectionHeader('1. Incident Information'),
                  const SizedBox(height: 12),

                  // Category
                  const Text(
                    'Incident Category *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: _inputDecoration(),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(
                      () => _selectedCategory = v ?? _selectedCategory,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title (Optional)
                  const Text(
                    'Report Title (Optional Summary)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      hint: 'e.g., Harassment incident near library corridor',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Detailed Description of What Happened *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _inputDecoration(
                      hint:
                          'Describe the incident in detail: what occurred, words spoken, physical actions, and ongoing safety concerns...',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please describe what happened'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Date & Time Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date of Incident *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_incidentDate.year}-${_incidentDate.month.toString().padLeft(2, '0')}-${_incidentDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time of Incident *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _incidentTime.format(context),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location / Setting Dropdown
                  const Text(
                    'Location on Campus / Setting *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocation,
                    decoration: _inputDecoration(),
                    items: _commonLocations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLocation = val;
                        });
                      }
                    },
                  ),
                  if (_selectedLocation == 'Other') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otherLocationController,
                      decoration: _inputDecoration(
                        hint: 'Please specify other location or setting',
                      ),
                      validator: (val) =>
                          _selectedLocation == 'Other' &&
                              (val == null || val.trim().isEmpty)
                          ? 'Please specify location'
                          : null,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Urgency Level
                  const Text(
                    'Urgency Level *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUrgency,
                    decoration: _inputDecoration(),
                    items: _urgencyLevels.map((u) {
                      Color color = Colors.blue;
                      if (u == 'Critical') color = Colors.red.shade700;
                      if (u == 'High') color = Colors.orange.shade700;
                      if (u == 'Moderate') color = Colors.amber.shade800;
                      return DropdownMenuItem(
                        value: u,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              u,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(
                      () => _selectedUrgency = v ?? _selectedUrgency,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section 2: Involved Students
                  _buildSectionHeader('2. Involved Students (If Known)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Provide any names or grade levels you are aware of to assist automatic grade assignment.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // Victim / Affected Student
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_pin,
                                  color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Victim / Subject Student (If Known)',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _victimNameController,
                            decoration: _inputDecoration(
                              hint: 'Student name (or leave blank if unknown)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final gradeField =
                                  DropdownButtonFormField<String>(
                                initialValue: _selectedVictimGrade,
                                isExpanded: true,
                                decoration: _inputDecoration(
                                  hint: 'Grade Level',
                                ),
                                items: _gradeLevels
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(
                                          g,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () => _selectedVictimGrade =
                                      v ?? _selectedVictimGrade,
                                ),
                              );
                              final sectionField = TextFormField(
                                controller: _victimSectionController,
                                decoration: _inputDecoration(
                                  hint: 'Section (e.g. Mahogany)',
                                ),
                              );

                              if (constraints.maxWidth < 360) {
                                return Column(
                                  children: [
                                    gradeField,
                                    const SizedBox(height: 10),
                                    sectionField,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: gradeField),
                                  const SizedBox(width: 10),
                                  Expanded(child: sectionField),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Alleged Bully / Offender
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFFD97706), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Alleged Bully / Involved Student (If Known)',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _bullyNameController,
                            decoration: _inputDecoration(
                              hint: 'Name of student(s) who committed the act',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _bullyGradeController,
                            decoration: _inputDecoration(
                              hint: 'Grade & Section (e.g. Grade 8 - Uranus)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Witnesses
                  const Text(
                    'Witnesses (Names separated by comma, optional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _witnessesController,
                    decoration: _inputDecoration(
                      hint: 'e.g. Juan Gomez, Maria Santos',
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Evidence file picker
                  const Text(
                    'Photo / Video Evidence (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Up to 5 files and 50 MB total. AI-generated images are not accepted. Automated screening only checks for detectable AI labels and does not confirm authenticity or acceptance. The Office of Student Discipline (OSD) will review every image and investigate each report.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickEvidenceFiles,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _selectedEvidenceFiles.isEmpty
                          ? 'Choose photo or video files'
                          : 'Choose more photo or video files',
                    ),
                  ),
                  if (_selectedEvidenceFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._selectedEvidenceFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final lowerName = file.name.toLowerCase();
                      final isVideo = [
                        '.mp4',
                        '.mov',
                        '.webm',
                        '.3gp',
                      ].any(lowerName.endsWith);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isVideo
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove file',
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _selectedEvidenceFiles.removeAt(index),
                                ),
                          icon: const Icon(Icons.close),
                        ),
                      );
                    }),
                    const Text(
                      'Files upload securely with the report (max 25 MB each).',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.send_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Submit Anonymous Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel & Return to Sign In',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
