import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Physical';
  String _selectedLocation = 'School Cafeteria';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<Map<String, dynamic>> _categories = [
    {
      'value': 'Physical',
      'label': 'Physical Bullying',
      'sub': 'Hitting, Shoving, Property Damage',
      'icon': Icons.gavel,
    },
    {
      'value': 'Verbal',
      'label': 'Verbal Bullying',
      'sub': 'Teasing, Name-calling, Threats',
      'icon': Icons.record_voice_over,
    },
    {
      'value': 'Social/Relational',
      'label': 'Social/Relational Bullying',
      'sub': 'Exclusion, Rumors, Humiliation',
      'icon': Icons.people_outline,
    },
    {
      'value': 'Cyber',
      'label': 'Cyberbullying',
      'sub': 'Online Harassment, Cyber-Stalking',
      'icon': Icons.devices_other,
    },
    {
      'value': 'Sexual',
      'label': 'Sexual Bullying',
      'sub': 'Harassment, Inappropriate Remarks',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'value': 'Prejudicial',
      'label': 'Prejudicial Bullying',
      'sub': 'Targeting Race, Religion, Orientation',
      'icon': Icons.public_off,
    },
    {
      'value': 'Other',
      'label': 'Other / Custom Incident',
      'sub': 'Any other bullying or harassment cases',
      'icon': Icons.help_outline,
    },
  ];

  final List<Map<String, dynamic>> _locations = [
    {'value': 'Classroom', 'label': 'Classroom', 'icon': Icons.meeting_room},
    {
      'value': 'Hallway / Corridors',
      'label': 'Hallway / Corridors',
      'icon': Icons.door_sliding,
    },
    {
      'value': 'School Cafeteria',
      'label': 'School Cafeteria',
      'icon': Icons.local_cafe,
    },
    {
      'value': 'Playground / Sports Field',
      'label': 'Playground / Sports Field',
      'icon': Icons.sports_soccer,
    },
    {'value': 'Restrooms', 'label': 'Restrooms', 'icon': Icons.wc},
    {
      'value': 'School Library',
      'label': 'School Library',
      'icon': Icons.local_library,
    },
    {'value': 'Gymnasium', 'label': 'Gymnasium', 'icon': Icons.fitness_center},
    {
      'value': 'Computer Laboratory',
      'label': 'Computer Laboratory',
      'icon': Icons.computer,
    },
    {
      'value': 'Science Laboratory',
      'label': 'Science Laboratory',
      'icon': Icons.science,
    },
    {'value': 'Faculty Room', 'label': 'Faculty Room', 'icon': Icons.badge},
    {
      'value': 'Administrative Office',
      'label': 'Administrative Office',
      'icon': Icons.corporate_fare,
    },
    {
      'value': 'Guidance Office',
      'label': 'Guidance Office',
      'icon': Icons.psychology,
    },
    {'value': 'Clinic', 'label': 'Clinic', 'icon': Icons.medical_services},
    {
      'value': 'School Gate / Entrance',
      'label': 'School Gate / Entrance',
      'icon': Icons.door_front_door,
    },
    {
      'value': 'Parking Lot',
      'label': 'Parking Lot',
      'icon': Icons.local_parking,
    },
    {
      'value': 'Near School Premises',
      'label': 'Near School Premises',
      'icon': Icons.near_me,
    },
    {
      'value': 'Other Location',
      'label': 'Other Location',
      'icon': Icons.location_on_outlined,
    },
  ];

  final List<SelectedMedia> _selectedMediaList = [];
  String _evidenceVerificationState = 'Unverified';
  String? _evidenceVerificationDetails;
  bool _isAnalyzingEvidence = false;
  bool _isSubmitting = false;

  final _db = DatabaseService();
  final _ai = AIService();

  final _bullyNameController = TextEditingController();
  final _bullyGradeSectionController = TextEditingController();
  final List<TextEditingController> _witnessControllers = [];

  void _addWitnessField() {
    setState(() {
      _witnessControllers.add(TextEditingController());
    });
  }

  void _removeWitnessField(int index) {
    setState(() {
      _witnessControllers[index].dispose();
      _witnessControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bullyNameController.dispose();
    _bullyGradeSectionController.dispose();
    for (var ctrl in _witnessControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();

      final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      final videosGranted = statuses[Permission.videos]?.isGranted ?? false;
      final storageGranted = statuses[Permission.storage]?.isGranted ?? false;

      if (!photosGranted && !videosGranted && !storageGranted) {
        _showPermissionDeniedDialog();
        return false;
      }
      return true;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
        return false;
      }
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Photo Library Access Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please enable Photo Library / Storage access in your device settings to select and upload evidence files.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadFile(
    PlatformFile platformFile,
    void Function(double progress) onProgress,
  ) async {
    try {
      final bytes =
          platformFile.bytes ??
          (platformFile.path == null
              ? null
              : await File(platformFile.path!).readAsBytes());
      if (bytes == null) throw Exception('File data is unavailable.');
      onProgress(0.1);
      return await _db.uploadEvidence(
        bytes: bytes,
        fileName: platformFile.name,
        contentType: _contentTypeFor(platformFile.name),
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  String? _contentTypeFor(String fileName) {
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
        return 'application/octet-stream';
    }
  }

  Future<void> _startUpload(SelectedMedia media) async {
    setState(() {
      media.uploadProgress = 0.0;
    });

    final url = await _uploadFile(media.file, (progress) {
      setState(() {
        media.uploadProgress = progress;
      });
    });

    setState(() {
      if (url != null) {
        media.uploadedUrl = url;
        media.uploadProgress = 1.0;
      } else {
        media.uploadProgress = -2.0;
      }
    });

    if (_selectedMediaList.isNotEmpty &&
        _selectedMediaList.first == media &&
        url != null) {
      await _analyzeEvidence(media.file.name);
    }
  }

  Future<void> _analyzeEvidence(String filename) async {
    setState(() {
      _isAnalyzingEvidence = true;
      _evidenceVerificationState = 'Verifying...';
      _evidenceVerificationDetails = null;
    });

    try {
      final result = await _ai.verifyEvidencePhoto(filename, 450.0);
      setState(() {
        _evidenceVerificationState = result.state;
        _evidenceVerificationDetails = result.details;
      });
    } catch (e) {
      setState(() {
        _evidenceVerificationState = 'Error';
        _evidenceVerificationDetails = 'Analysis failed: $e';
      });
    } finally {
      setState(() {
        _isAnalyzingEvidence = false;
      });
    }
  }

  Future<void> _pickFileFromDevice() async {
    try {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) return;

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          final media = SelectedMedia(file: file);
          setState(() {
            _selectedMediaList.add(media);
          });
          _startUpload(media);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMediaList.removeAt(index);
      if (_selectedMediaList.isEmpty) {
        _evidenceVerificationState = 'Unverified';
        _evidenceVerificationDetails = null;
      } else {
        _analyzeEvidence(_selectedMediaList.first.file.name);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if any uploads are in progress
    final hasOngoingUploads = _selectedMediaList.any(
      (m) => m.uploadProgress >= 0.0 && m.uploadProgress < 1.0,
    );
    if (hasOngoingUploads) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for file attachment upload to finish.'),
        ),
      );
      return;
    }

    // 1. Combine Date and Time
    final incidentDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Validate that the incidentDateTime is not in the future
    if (incidentDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a valid date. Future dates are not allowed.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final witnessesList = _witnessControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final evidenceUrls = _selectedMediaList
          .map((m) => m.uploadedUrl)
          .where((u) => u != null)
          .join(',');

      // Non-blocking screening state
      final screeningState = evidenceUrls.isNotEmpty
          ? (_evidenceVerificationState == 'Verifying...'
                ? 'Screening: Processing'
                : _evidenceVerificationState)
          : 'Unverified';

      // 2. Immediate Immutable Save (Parent is never blocked by AI latency)
      final newReport = await _db.submitReport(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        incidentDate: incidentDateTime,
        incidentLocation: _selectedLocation,
        evidenceUrl: evidenceUrls.isEmpty ? null : evidenceUrls,
        evidenceVerificationState: screeningState,
        evidenceVerificationDetails: _evidenceVerificationDetails,
        aiSummary: null, // Populated asynchronously
        bullyName: _bullyNameController.text.trim().isEmpty
            ? null
            : _bullyNameController.text.trim(),
        bullyGradeSection: _bullyGradeSectionController.text.trim().isEmpty
            ? null
            : _bullyGradeSectionController.text.trim(),
        witnesses: witnessesList.isEmpty ? null : witnessesList,
        studentId: _db.selectedChild?.id,
      );

      // 3. Asynchronous background category validation & digest generation
      unawaited(() async {
        try {
          final summary = await _ai.generateReportSummary(
            title: newReport.title,
            description: newReport.description,
            category: newReport.category,
            location: newReport.incidentLocation,
          );
          await _db.updateAiSummary(newReport.id, summary);
        } catch (_) {}
      }());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident report submitted successfully. Official case created.',
          ),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(); // Back to dashboard immediately
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = _db.currentUser;
    if (parent == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'File Bullying Incident Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Information Banner (Read-only Student details)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Verified Student Information (Read-Only)',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildReadOnlyField(
                                'Student Name',
                                _db.selectedChild?.name ?? 'N/A',
                              ),
                            ),
                            Expanded(
                              child: _buildReadOnlyField(
                                'Section & Grade',
                                _db.selectedChild != null
                                    ? '${_db.selectedChild!.grade} - ${_db.selectedChild!.section}'
                                    : 'N/A',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Report Details Section
                  const Text(
                    'Incident Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Report Title / Heading',
                      Icons.title,
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please enter a title'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Category & Date-Time Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            'Category',
                            Icons.category_outlined,
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return _categories.map<Widget>((cat) {
                              return Text(
                                cat['label']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              );
                            }).toList();
                          },
                          items: _categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat['value'],
                              child: Row(
                                children: [
                                  Icon(
                                    cat['icon'] as IconData,
                                    color: Colors.blueAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          cat['label']!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          cat['sub']!,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocation,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Incident Location',
                      Icons.location_on_outlined,
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return _locations.map<Widget>((loc) {
                        return Text(
                          loc['label']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        );
                      }).toList();
                    },
                    items: _locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc['value'],
                        child: Row(
                          children: [
                            Icon(
                              loc['icon'] as IconData,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              loc['label']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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
                  const SizedBox(height: 16),

                  // Date and Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              'Date of Incident',
                              Icons.calendar_today_outlined,
                            ),
                            child: Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _selectTime,
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              'Time of Incident',
                              Icons.access_time_outlined,
                            ),
                            child: Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Detailed Description of Incident',
                      Icons.description_outlined,
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please describe what happened'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Alleged Bully Section
                  const Text(
                    'Who is the Alleged Bully? (Optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bullyNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Alleged Bully Full Name',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bullyGradeSectionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Grade & Section (if known)',
                      Icons.class_outlined,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Witnesses Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Who are the Witnesses? (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addWitnessField,
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                        label: const Text(
                          'Add Witness',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_witnessControllers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'No witnesses added yet. Click "Add Witness" to add one.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _witnessControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _witnessControllers[index],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    'Witness Name #${index + 1}',
                                    Icons.people_outline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeWitnessField(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  // Evidence Picker Section
                  const Text(
                    'Attach Evidence Photo (Optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload an image showing the incident. The system will scan and verify authenticity using AI analysis.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Choose Custom File from Device Button (Permanently visible)
                  ElevatedButton.icon(
                    onPressed: _pickFileFromDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.upload_file_outlined,
                      color: Colors.blueAccent,
                    ),
                    label: const Text(
                      'Choose File from Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Evidence display
                  if (_selectedMediaList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Media Gallery',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: _selectedMediaList.length,
                            itemBuilder: (context, index) {
                              final media = _selectedMediaList[index];
                              final isVideo =
                                  media.file.name.toLowerCase().endsWith(
                                    '.mp4',
                                  ) ||
                                  media.file.name.toLowerCase().endsWith(
                                    '.mov',
                                  );

                              Widget previewWidget;
                              if (isVideo) {
                                previewWidget = Container(
                                  color: const Color(0xFF0F172A),
                                  child: const Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.videocam_outlined,
                                        color: Colors.white30,
                                        size: 36,
                                      ),
                                      Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white70,
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                if (kIsWeb && media.file.bytes != null) {
                                  previewWidget = Image.memory(
                                    media.file.bytes!,
                                    fit: BoxFit.cover,
                                  );
                                } else if (media.file.path != null) {
                                  previewWidget = Image.file(
                                    File(media.file.path!),
                                    fit: BoxFit.cover,
                                  );
                                } else {
                                  previewWidget = Container(
                                    color: const Color(0xFF0F172A),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: Colors.white24,
                                      size: 36,
                                    ),
                                  );
                                }
                              }

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    previewWidget,

                                    // Upload Progress Overlay
                                    if (media.uploadProgress >= 0.0 &&
                                        media.uploadProgress < 1.0)
                                      Container(
                                        color: Colors.black54,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(
                                                value: media.uploadProgress,
                                                strokeWidth: 3,
                                                color: const Color(0xFF6366F1),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${(media.uploadProgress * 100).toInt()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Upload Success Overlay
                                    if (media.uploadProgress == 1.0)
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),

                                    // Upload Error Overlay
                                    if (media.uploadProgress == -2.0)
                                      Container(
                                        color: Colors.black54,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: Colors.redAccent,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () =>
                                                    _startUpload(media),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF6366F1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Retry',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Delete/Cancel button
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeMedia(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white70,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Divider(color: Color(0xFF334155), height: 24),
                          Row(
                            children: [
                              const Text(
                                'AI Verification Status:',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_isAnalyzingEvidence)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _evidenceVerificationState == 'Verified'
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _evidenceVerificationState.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          _evidenceVerificationState ==
                                              'Verified'
                                          ? Colors.green
                                          : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_evidenceVerificationDetails != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'AI Analysis Details:',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _evidenceVerificationDetails!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isSubmitting || _isAnalyzingEvidence
                        ? null
                        : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
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
                              Text('AI Auto-Summarizing & Registering Case...'),
                            ],
                          )
                        : const Text(
                            'Submit Bullying Report',
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
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey, size: 18),
      filled: true,
      fillColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.0),
      ),
    );
  }
}

class SelectedMedia {
  final PlatformFile file;
  double
  uploadProgress; // -1.0 = not started, -2.0 = error, 0.0 to 1.0 = progress
  String? uploadedUrl;

  SelectedMedia({
    required this.file,
    this.uploadProgress = -1.0,
    this.uploadedUrl,
  });
}
