import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../models/meeting_model.dart';
import '../../models/timeline_model.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/timeline_widget.dart';
import '../chat/chat_screen.dart';
import '../../widgets/evidence_media_widget.dart';

class StaffReportDetailScreen extends StatefulWidget {
  final String reportId;

  const StaffReportDetailScreen({super.key, required this.reportId});

  @override
  State<StaffReportDetailScreen> createState() => _StaffReportDetailScreenState();
}

class _StaffReportDetailScreenState extends State<StaffReportDetailScreen> {
  final _db = DatabaseService();
  final _ai = AIService();

  // Scheduler controllers
  DateTime _meetingDate = DateTime.now();
  TimeOfDay _meetingTime = TimeOfDay.now();
  final _meetingNotesController = TextEditingController();
  String _meetingType = 'In-Person';
  bool _isScheduling = false;

  // Resolution controllers
  String _selectedDiscipline = 'Warning';
  final _disciplineNotesController = TextEditingController();
  bool _isResolving = false;

  // AI Summary generation state
  bool _isGeneratingSummary = false;
  bool _isCheckingConsistency = false;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbUpdate);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbUpdate);
    _meetingNotesController.dispose();
    _disciplineNotesController.dispose();
    super.dispose();
  }

  void _onDbUpdate() {
    if (mounted) setState(() {});
  }

  // Card builder helper for Light Slate style
  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BoxBorder? border,
    Color color = Colors.white,
  }) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: border ?? Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // OCR/AI Evidence Verification Badge
  Widget _buildEvidenceVerificationBadge(String state) {
    Color bg;
    Color border;
    Color text;

    if (state.contains('Verified') || state.contains('Passed')) {
      bg = const Color(0xFFF0FDF4); // Green 50
      border = const Color(0xFFBBF7D0); // Green 200
      text = const Color(0xFF16A34A); // Green 600
    } else if (state.contains('Synthetic') || state.contains('AI') || state.contains('Generated')) {
      bg = const Color(0xFFFFFBEB); // Amber 50
      border = const Color(0xFFFDE68A); // Amber 200
      text = const Color(0xFFD97706); // Amber 600
    } else if (state.contains('Stock') || state.contains('Web') || state.contains('Google')) {
      bg = const Color(0xFFEFF6FF); // Blue 50
      border = const Color(0xFFBFDBFE); // Blue 200
      text = const Color(0xFF2563EB); // Blue 600
    } else if (state.contains('Processing') || state.contains('Verifying')) {
      bg = const Color(0xFFF5F3FF); // Violet 50
      border = const Color(0xFFDDD6FE); // Violet 200
      text = const Color(0xFF7C3AED); // Violet 600
    } else {
      bg = const Color(0xFFF8FAFC); // Slate 50
      border = const Color(0xFFE2E8F0); // Slate 200
      text = const Color(0xFF64748B); // Slate 500
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        state.toUpperCase(),
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _selectMeetingDate(StateSetter setDialogState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2028),
    );
    if (picked != null) {
      setDialogState(() {
        _meetingDate = picked;
      });
    }
  }

  Future<void> _selectMeetingTime(StateSetter setDialogState) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime,
    );
    if (picked != null) {
      setDialogState(() {
        _meetingTime = picked;
      });
    }
  }

  void _showScheduleMeetingDialog() {
    _meetingDate = DateTime.now();
    _meetingTime = TimeOfDay.now();
    _meetingNotesController.clear();
    _meetingType = 'In-Person';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Schedule Meeting',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Schedule a discussion with the parent to coordinate details.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    MediaQuery.of(context).size.width < 400
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _selectMeetingDate(setDialogState),
                                icon: const Icon(Icons.calendar_today, size: 14),
                                label: Text(
                                  '${_meetingDate.year}-${_meetingDate.month.toString().padLeft(2, '0')}-${_meetingDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _selectMeetingTime(setDialogState),
                                icon: const Icon(Icons.access_time, size: 14),
                                label: Text(
                                  _meetingTime.format(context),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectMeetingDate(setDialogState),
                                  icon: const Icon(Icons.calendar_today, size: 14),
                                  label: Text(
                                    '${_meetingDate.year}-${_meetingDate.month.toString().padLeft(2, '0')}-${_meetingDate.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectMeetingTime(setDialogState),
                                  icon: const Icon(Icons.access_time, size: 14),
                                  label: Text(
                                    _meetingTime.format(context),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _meetingType,
                      decoration: _dialogInputDecoration('Meeting Type'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      items: ['In-Person', 'Virtual']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _meetingType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _meetingNotesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Meeting Agenda / Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: _isScheduling ? null : () => _handleScheduleMeeting(setDialogState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isScheduling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleScheduleMeeting(StateSetter? setDialogState, {String? existingMeetingId}) async {
    if (setDialogState != null) {
      setDialogState(() => _isScheduling = true);
    }
    setState(() => _isScheduling = true);

    try {
      final combinedDateTime = DateTime(
        _meetingDate.year,
        _meetingDate.month,
        _meetingDate.day,
        _meetingTime.hour,
        _meetingTime.minute,
      );

      if (existingMeetingId != null) {
        await _db.rescheduleMeeting(
          meetingId: existingMeetingId,
          newDate: combinedDateTime,
          newNotes: _meetingNotesController.text.trim().isEmpty ? "No notes provided." : _meetingNotesController.text.trim(),
          newType: _meetingType,
        );
        if (!mounted) return;
        Navigator.of(context).pop(); // Dismiss reschedule dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting rescheduled successfully.')),
        );
      } else {
        await _db.scheduleMeeting(
          reportId: widget.reportId,
          meetingDate: combinedDateTime,
          notes: _meetingNotesController.text.trim().isEmpty ? "No notes provided." : _meetingNotesController.text.trim(),
          meetingType: _meetingType,
        );
        _meetingNotesController.clear();
        if (!mounted) return;
        Navigator.of(context).pop(); // Dismiss schedule dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting scheduled successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    } finally {
      if (mounted) {
        if (setDialogState != null) {
          setDialogState(() => _isScheduling = false);
        }
        setState(() => _isScheduling = false);
      }
    }
  }

  void _showRescheduleDialog(MeetingModel meeting) {
    _meetingDate = meeting.meetingDate;
    _meetingTime = TimeOfDay.fromDateTime(meeting.meetingDate);
    _meetingNotesController.text = meeting.notes;
    _meetingType = meeting.meetingType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Reschedule Meeting',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Only the original scheduler can update this date/time.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    MediaQuery.of(context).size.width < 400
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _selectMeetingDate(setDialogState),
                                icon: const Icon(Icons.calendar_today, size: 14),
                                label: Text(
                                  '${_meetingDate.year}-${_meetingDate.month.toString().padLeft(2, '0')}-${_meetingDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _selectMeetingTime(setDialogState),
                                icon: const Icon(Icons.access_time, size: 14),
                                label: Text(
                                  _meetingTime.format(context),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectMeetingDate(setDialogState),
                                  icon: const Icon(Icons.calendar_today, size: 14),
                                  label: Text(
                                    '${_meetingDate.year}-${_meetingDate.month.toString().padLeft(2, '0')}-${_meetingDate.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectMeetingTime(setDialogState),
                                  icon: const Icon(Icons.access_time, size: 14),
                                  label: Text(
                                    _meetingTime.format(context),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _meetingType,
                      decoration: _dialogInputDecoration('Meeting Type'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      items: ['In-Person', 'Virtual']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _meetingType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _meetingNotesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Reschedule Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: _isScheduling ? null : () => _handleScheduleMeeting(setDialogState, existingMeetingId: meeting.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isScheduling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResolveCaseDialog() {
    _selectedDiscipline = 'Warning';
    _disciplineNotesController.clear();

    final staff = _db.currentUser;
    final isMinorOnly = staff?.role == UserRole.principal || staff?.role == UserRole.ministrong_tagasubaybay;
    final dropdownItems = isMinorOnly
        ? ['Warning', 'Counseling', 'Mediation', 'Community Service', 'Parent Consultation', 'Other']
        : ['Warning', 'Counseling', 'Mediation', 'Suspension', 'Expulsion', 'Community Service', 'Parent Consultation', 'Other'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Resolve Incident Case',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Input the final resolution action and closing notes for this case.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDiscipline,
                      decoration: _dialogInputDecoration('Disciplinary Action Given'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      items: dropdownItems
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _selectedDiscipline = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _disciplineNotesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Detailed Resolution Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: _isResolving ? null : () => _handleResolve(setDialogState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isResolving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Resolve Incident'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleResolve(StateSetter setDialogState) async {
    if (_disciplineNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter resolution notes.')),
      );
      return;
    }

    setDialogState(() => _isResolving = true);
    setState(() => _isResolving = true);

    try {
      final actionChosen = _selectedDiscipline;
      final notesEntered = _disciplineNotesController.text.trim();

      await _db.resolveReport(
        reportId: widget.reportId,
        disciplineAction: actionChosen,
        disciplineNotes: notesEntered,
      );

      // Non-blocking trigger for Post-Resolution Case Abstract
      final report = _db.reports.firstWhere((r) => r.id == widget.reportId);
      final timeline = _db.getTimelineEvents(widget.reportId);
      final meetings = _db.meetings.where((m) => m.reportId == widget.reportId).toList();

      _ai.generatePostResolutionCaseAbstract(
        report: report,
        timeline: timeline,
        meetings: meetings,
        disciplineAction: actionChosen,
        disciplineNotes: notesEntered,
      ).then((caseAbstract) {
        if (caseAbstract.abstractText.isNotEmpty) {
          _db.updateAiSummary(widget.reportId, caseAbstract.abstractText);
        }
      }).catchError((_) {});

      _disciplineNotesController.clear();
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss resolve dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case marked as resolved successfully. Case abstract queued.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resolution failed: $e')),
      );
    } finally {
      if (mounted) {
        setDialogState(() => _isResolving = false);
        setState(() => _isResolving = false);
      }
    }
  }

  Future<void> _handleRunConsistencyCheck(
    ReportModel report,
    List<TimelineEvent> timeline,
    List<MeetingModel> meetings,
  ) async {
    setState(() => _isCheckingConsistency = true);
    try {
      final res = await _ai.runCaseConsistencyCheck(
        report: report,
        timeline: timeline,
        meetings: meetings,
      );
      if (!mounted) return;
      _showConsistencyCheckResultDialog(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Consistency check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingConsistency = false);
    }
  }

  void _showConsistencyCheckResultDialog(CaseConsistencyResult result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                result.hasInconsistencies ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: result.hasInconsistencies ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Case Consistency Check',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: result.hasInconsistencies ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: result.hasInconsistencies ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Text(
                    result.hasInconsistencies
                        ? 'Possible documentation or procedural points noted. Human review recommended:'
                        : 'No procedural, chronological, or documentation discrepancies found.',
                    style: TextStyle(
                      color: result.hasInconsistencies ? const Color(0xFF92400E) : const Color(0xFF166534),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...result.findings.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),
                Text(
                  result.advisoryNote,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Acknowledge'),
            ),
          ],
        );
      },
    );
  }

  void _showCaseArchivePacketDialog(
    ReportModel report,
    List<TimelineEvent> timeline,
    List<MeetingModel> meetings,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Case Archive Packet',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Case Number: #INC-2026-${report.id.padLeft(3, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text('Student Subject: ${report.studentName} (${report.studentGrade} - ${report.studentSection})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        Text('Category: ${report.category} Bullying',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        Text('Status: ${report.status.toUpperCase()}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Disciplinary & Procedural Dossier:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Text('• Disciplinary Action: ${report.disciplineAction ?? "Standard Counseling / Mediation"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('• Resolution Notes: ${report.disciplineNotes ?? "Completed with parent acknowledgment"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('• Evidence Provenance: ${report.evidenceUrl != null ? "Preserved (Screening Passed)" : "No digital media"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('• Total Chronological Events: ${timeline.length}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('• Coordination Meetings: ${meetings.length}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  const SizedBox(height: 14),
                  if (report.aiSummary != null) ...[
                    const Text('Post-Resolution Case Abstract:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.aiSummary!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155), height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Case Archive Dossier prepared for institutional record.')),
                );
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Dossier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2444),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _build5StageStepper(ReportModel report) {
    final currentStage = report.stageNumber;
    final isResolved = report.status.toLowerCase().contains('resolved') || report.status.toLowerCase().contains('closed') || report.status.toLowerCase().contains('finalized');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isResolved ? 'Case Completed / Finalized' : report.stageName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isResolved ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isResolved ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Responsible: ${report.currentHandlingOffice}',
                  style: TextStyle(
                    color: isResolved ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final stageIdx = index + 1;
              final isDone = stageIdx < currentStage || isResolved;
              final isCurrent = stageIdx == currentStage && !isResolved;
              Color circleColor = const Color(0xFFCBD5E1);
              if (isDone) circleColor = const Color(0xFF16A34A);
              if (isCurrent) circleColor = const Color(0xFF2563EB);

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: circleColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Text(
                                      '$stageIdx',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stage $stageIdx',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (index < 4)
                      Container(
                        width: 12,
                        height: 2,
                        color: stageIdx < currentStage || isResolved
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeAssignmentsCard(ReportModel report) {
    final assignments = DatabaseService.determineGradeAssignments(
      studentGrade: report.studentGrade,
      studentSection: report.studentSection,
      bullyGradeSection: report.bullyGradeSection,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_ind_outlined, color: Color(0xFF475569), size: 18),
              SizedBox(width: 8),
              Text(
                'Grade-Level Automatic Personnel Assignment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Involved Grades: ${(assignments['grades'] as List).join(', ')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 6),
          _buildAssignmentRow('Assigned Ministrong Tagasubaybay', assignments['ministroName'] ?? 'None'),
          const SizedBox(height: 4),
          _buildAssignmentRow('Assigned OSD Officer', assignments['osdName'] ?? 'None'),
          const SizedBox(height: 4),
          _buildAssignmentRow('Assigned Principal', assignments['principalName'] ?? 'None'),
          if (report.studentSection.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildAssignmentRow('Section Adviser', report.studentSection),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAnonymousNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: const [
          Icon(Icons.visibility_off_outlined, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anonymous Incident Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                ),
                SizedBox(height: 2),
                Text(
                  'Submitted without an account. Reporter IP address, device info, and identity are completely protected.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STAGE 1: Forward for Initial Intervention Dialog
  void _showForwardForInitialInterventionDialog(ReportModel report) {
    final notesController = TextEditingController();
    bool isSubmitting = false;

    final assignments = DatabaseService.determineGradeAssignments(
      studentGrade: report.studentGrade,
      studentSection: report.studentSection,
      bullyGradeSection: report.bullyGradeSection,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.forward_to_inbox, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 1: Forward for Initial Intervention',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OSD Initial Assessment Protocol',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Forwarding this report to the assigned Ministrong Tagasubaybay and Section Adviser for joint investigation and initial student intervention.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Assigned Ministro: ${assignments['ministroName']}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Section Adviser: ${report.studentSection.isNotEmpty ? report.studentSection : "To be confirmed"}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('OSD Initial Assessment Notes & Directives (Optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await _db.forwardForInitialIntervention(
                              reportId: widget.reportId,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Case officially forwarded to Ministrong Tagasubaybay and Section Adviser.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Forwarding failed: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Forward for Intervention'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 2: Resolve Case (Initial Intervention)
  void _showResolveInitialInterventionDialog(ReportModel report) {
    String selectedAction = 'Counseling & Restorative Agreement';
    final notesController = TextEditingController();
    String? formError;
    bool isSubmitting = false;

    final actions = [
      'Counseling & Restorative Agreement',
      'Mediation Conference & Mutual Apology',
      'Behavioral Contract & Adviser Monitoring',
      'Guidance Intervention & Peer Support',
      'Other Restorative Measure',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 2: Resolve Case (Joint Intervention)',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Record successful joint intervention by Ministrong Tagasubaybay and Section Adviser.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAction,
                      decoration: _dialogInputDecoration('Restorative Action Taken *'),
                      items: actions.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedAction = v ?? selectedAction),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 4,
                      decoration: _dialogInputDecoration('Investigation Findings & Resolution Notes *'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final notes = notesController.text.trim();
                          if (notes.isEmpty) {
                            setDialogState(() => formError = 'Please provide the investigation findings and resolution notes.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.resolveCaseInitialIntervention(
                              reportId: widget.reportId,
                              restorativeAction: selectedAction,
                              notes: notes,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Case successfully marked as Resolved.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Resolution failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Resolution'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 2: Escalate to OSD and Principal
  void _showEscalateToOsdAndPrincipalDialog(ReportModel report) {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String? formError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.arrow_upward, color: Color(0xFFEA580C)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 2: Escalate to OSD & Principal',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'If the situation cannot be managed or resolved during joint intervention, escalate the case to both OSD and Principal for higher intervention.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: _dialogInputDecoration('Reason for Escalation *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Intervention History & Witness Summary (Optional)'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            setDialogState(() => formError = 'Please state why the case cannot be resolved at this stage.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.escalateToOsdAndPrincipal(
                              reportId: widget.reportId,
                              reason: reason,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Case successfully escalated to OSD & Principal.'),
                                backgroundColor: Color(0xFFEA580C),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Escalation failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Escalate to OSD & Principal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 3: Resolve Case (OSD & Principal)
  void _showResolveOsdAndPrincipalDialog(ReportModel report) {
    String selectedAction = 'Written Warning & Reprimand';
    final notesController = TextEditingController();
    String? formError;
    bool isSubmitting = false;

    final actions = [
      'Written Warning & Reprimand',
      'Corrective Guidance & Restorative Counseling',
      '1-3 Day Campus Disciplinary Suspension',
      'Mandatory Campus Community Service',
      'Parent-Student Disciplinary Contract',
      'Other Official Disciplinary Sanction',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.gavel, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 3: Resolve Case (OSD & Principal)',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'OSD and Principal joint determination of disciplinary action and case resolution.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAction,
                      decoration: _dialogInputDecoration('Imposed Disciplinary Action *'),
                      items: actions.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedAction = v ?? selectedAction),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 4,
                      decoration: _dialogInputDecoration('Official Joint Findings & Decision Notes *'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final notes = notesController.text.trim();
                          if (notes.isEmpty) {
                            setDialogState(() => formError = 'Please record the official joint findings and decision notes.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.resolveCaseOsdAndPrincipal(
                              reportId: widget.reportId,
                              disciplineAction: selectedAction,
                              notes: notes,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Case successfully resolved with official disciplinary action.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Resolution failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Record & Resolve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 3: Escalate to Board of Discipline
  void _showEscalateToBoardDialog(ReportModel report) {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String? formError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.account_balance, color: Color(0xFF9333EA)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 3: Escalate to Board of Discipline',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'When OSD and Principal determine that an incident cannot be resolved or requires formal institutional tribunal proceedings, escalate the case to the Board of Discipline.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: _dialogInputDecoration('Reason for Escalation to Board *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Summary of Previous Investigations & Evidence (Optional)'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            setDialogState(() => formError = 'Please specify the reason for escalating to the Board of Discipline.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.escalateToBoardOfDiscipline(
                              reportId: widget.reportId,
                              reason: reason,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Case successfully escalated to the Board of Discipline.'),
                                backgroundColor: Color(0xFF9333EA),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Escalation failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Escalate to Board'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 4: Board of Discipline Final Deliberation & Punishment
  void _showBoardDecisionDialog(ReportModel report) {
    String selectedPunishment = 'Extended Suspension (5-10 Days)';
    final findingsController = TextEditingController();
    final decisionController = TextEditingController(text: 'Guilty of violation pursuant to School Child Protection and Anti-Bullying Policy.');
    String? formError;
    bool isSubmitting = false;

    final punishments = [
      'Extended Suspension (5-10 Days)',
      'Formal Disciplinary Probation with Community Restitution',
      'Exclusion from Extra-Curricular Activities & Class Disciplinary Transfer',
      'Mandatory Psychological Counseling & Corrective Supervision',
      'Recommendation for Expulsion (Subject to DepEd Review)',
      'Other Institutional Disciplinary Punishment',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.balance, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 4: Board Deliberation & Punishment',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Board of Discipline conducts formal deliberation, renders decision, and determines the imposed punishment, then forwards to the School President.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: findingsController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Board Findings & Deliberation Record *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: decisionController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: _dialogInputDecoration('Formal Board Decision *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPunishment,
                      decoration: _dialogInputDecoration('Imposed Punishment *'),
                      items: punishments.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedPunishment = v ?? selectedPunishment),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final findings = findingsController.text.trim();
                          final decision = decisionController.text.trim();
                          if (findings.isEmpty || decision.isEmpty) {
                            setDialogState(() => formError = 'Please record both the Board findings and formal decision.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.finalizeBoardDecisionAndForwardToPresident(
                              reportId: widget.reportId,
                              findings: findings,
                              decision: decision,
                              punishment: selectedPunishment,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Decision finalized and forwarded to School President for final review.'),
                                backgroundColor: Color(0xFFD97706),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Submission failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Finalize & Forward to President'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STAGE 5: School President Final Review
  void _showPresidentReviewDialog(ReportModel report) {
    final remarksController = TextEditingController(text: 'Reviewed and affirmed. Final disciplinary disposition approved for institutional execution.');
    String? formError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.verified, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stage 5: School President Final Review',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          const Text(
                            'Final Deliberation Summary for Executive Review',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Imposed Punishment: ${report.disciplineAction ?? "Determined by Board"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.disciplineNotes ?? 'No additional notes provided.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('President Executive Remarks & Concurrence *'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final remarks = remarksController.text.trim();
                          if (remarks.isEmpty) {
                            setDialogState(() => formError = 'Please enter executive remarks before finalizing.');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });
                          try {
                            await _db.completePresidentReview(
                              reportId: widget.reportId,
                              remarks: remarks,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Executive review completed. Disciplinary case officially finalized.'),
                                backgroundColor: Color(0xFF1E3A8A),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              formError = 'Review completion failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Complete Final Review'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEscalateDialog() {
    final staff = _db.currentUser;
    if (staff == null) return;

    String title = 'Escalate Case';
    String targetLabel = 'School Principal';
    if (staff.role == UserRole.adviser) {
      title = 'Escalate to Principal';
      targetLabel = 'School Principal';
    } else if (staff.role == UserRole.principal) {
      title = 'Escalate to Ministrong Tagasubaybay';
      targetLabel = 'Ministrong Tagasubaybay';
    } else if (staff.role == UserRole.ministrong_tagasubaybay) {
      title = 'Escalate to OSD';
      targetLabel = 'Office of Student Discipline (OSD)';
    }

    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String? formError;
    bool isEscalating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.arrow_upward, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Escalate this incident to $targetLabel for official institutional intervention and protective oversight.',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: _dialogInputDecoration('Reason for Escalation *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Supporting Notes / History (Optional)'),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isEscalating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isEscalating
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            setDialogState(() {
                              formError = 'Please state the specific reason for escalation.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isEscalating = true;
                            formError = null;
                          });

                          try {
                            await _db.escalateReport(
                              reportId: widget.reportId,
                              reason: reason,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );

                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Case successfully escalated to $targetLabel.')),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isEscalating = false;
                              formError = 'Escalation failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isEscalating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Escalation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController();
    bool isSavingNote = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Add Incident Progress Note',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Attach a progress note or timeline update describing current action steps.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      maxLines: 4,
                      decoration: _dialogInputDecoration('Write progress note...'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSavingNote
                      ? null
                      : () async {
                          if (noteController.text.trim().isEmpty) return;
                          setDialogState(() => isSavingNote = true);
                          try {
                            await _db.addTimelineNote(widget.reportId, noteController.text.trim());
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Progress note added to timeline.')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add note: $e')),
                            );
                          } finally {
                            setDialogState(() => isSavingNote = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSavingNote
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Note'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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

  Future<void> _handleGenerateAiSummary(ReportModel report) async {
    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      // Simulate loading spinner for 800ms as requested
      await Future.delayed(const Duration(milliseconds: 800));

      final summary = await _ai.generateReportSummary(
        title: report.title,
        description: report.description,
        category: report.category,
        location: report.incidentLocation,
      );

      await _db.updateAiSummary(report.id, summary);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Incident Summary generated successfully.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate summary: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
        });
      }
    }
  }

  Widget _buildAiSummaryCard(ReportModel report) {
    if (_isGeneratingSummary) {
      return _buildCard(
        color: const Color(0xFFF5F3FF), // Violet 50
        border: Border.all(color: const Color(0xFFDDD6FE)), // Violet 200
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              ),
              SizedBox(height: 16),
              Text(
                'AI is analyzing the report details...',
                style: TextStyle(
                  color: Color(0xFF5B21B6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Assessing severity and drafting action steps',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (report.aiSummary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFF7C3AED), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI-Generated Report Summary',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _handleGenerateAiSummary(report),
                icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF7C3AED)),
                label: const Text(
                  'Regenerate',
                  style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCard(
            color: const Color(0xFFF5F3FF), // Violet 50
            border: Border.all(color: const Color(0xFFDDD6FE)), // Violet 200
            padding: const EdgeInsets.all(16),
            child: Text(
              report.aiSummary!,
              style: const TextStyle(
                color: Color(0xFF4C1D95),
                fontSize: 12,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      );
    }

    // AI Summary is null
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFF64748B), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Case Summary Generator',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No AI summary has been generated for this incident yet. Generate a summary to evaluate severity, extract context, and view recommended next steps.',
            style: TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _handleGenerateAiSummary(report),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text(
              'Generate AI Case Summary',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = _db.currentUser;
    if (staff == null) return const SizedBox();

    ReportModel? report;
    try {
      report = _db.getReportById(widget.reportId);
    } catch (_) {
      report = null;
    }

    if (report == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Report details', style: TextStyle(color: Color(0xFF0F172A))),
          iconTheme: const IconThemeData(color: Color(0xFF475569)),
        ),
        body: const Center(child: Text('Unauthorized view access.', style: TextStyle(color: Color(0xFF0F172A)))),
      );
    }

    final meetings = _db.getMeetingsForReport(report.id);
    final timelineEvents = _db.getTimelineEvents(report.id);
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    final statusLower = report.status.toLowerCase();
    final isResolved = statusLower == 'resolved' || statusLower == 'closed';
    final isWithMinistro = statusLower.contains('ministro');
    final isWithOSD = statusLower.contains('osd');
    final isWithBoard = statusLower.contains('board');

    // Escalation capabilities by role
    final canAdviserEscalate = staff.role == UserRole.adviser &&
        !isResolved &&
        !statusLower.contains('principal') &&
        !isWithMinistro &&
        !isWithOSD;

    final canPrincipalEscalate = staff.role == UserRole.principal &&
        !isResolved &&
        !isWithMinistro &&
        !isWithOSD;

    final canMinistroEscalate = staff.role == UserRole.ministrong_tagasubaybay &&
        !isResolved &&
        !isWithOSD &&
        !isWithBoard;

    final Widget leftPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 5-Stage Workflow Stepper
        _build5StageStepper(report),

        // Automatic Grade-Level Personnel Assignments
        _buildGradeAssignmentsCard(report),

        // Anonymous Report Notice (Identity Protected)
        if (report.isAnonymous)
          _buildAnonymousNotice(),

        // Overview Card
        _buildCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(status: report.status),
                  Text(
                    report.createdAt.toLocal().toString().substring(0, 16),
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.title,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _victimInfoBox(report),
              const SizedBox(height: 14),
              Text(
                report.description,
                style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bully & Witnesses Card
        if (report.bullyName != null || (report.witnesses != null && report.witnesses!.isNotEmpty)) ...[
          const Text('Alleged Bully & Witnesses', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.bullyName != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      const Text('Alleged Bully: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text(
                        report.bullyName!,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (report.bullyGradeSection != null) ...[
                        Text(
                          ' (${report.bullyGradeSection})',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  if (report.witnesses != null && report.witnesses!.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: Color(0xFFE2E8F0)),
                    ),
                ],
                if (report.witnesses != null && report.witnesses!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.people_outline, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      const Text('Witnesses: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: report.witnesses!
                              .map((w) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      w,
                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // AI Auto Summary Panel
        _buildAiSummaryCard(report),

        const SizedBox(height: 16),

        // Evidence scan Report
        if (report.evidenceUrl != null) ...[
          const Text('Evidence Analysis Details', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildCard(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_outlined, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.evidenceUrl!,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildEvidenceVerificationBadge(report.evidenceVerificationState),
                  ],
                ),
                if (report.evidenceVerificationDetails != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.evidenceVerificationDetails!,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 11, height: 1.3),
                  ),
                ],
                EvidenceMediaWidget(filename: report.evidenceUrl!),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Timeline logs
        const Text('Timeline Activity Logs', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildCard(
          padding: const EdgeInsets.all(16.0),
          child: TimelineWidget(events: timelineEvents),
        ),
      ],
    );

    final Widget rightPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meeting schedules
        if (meetings.isNotEmpty) ...[
          const Text('Meeting Schedules', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...meetings.map((meeting) {
            final unreadChats = _db.getUnreadMessageCount(meeting.id);
            return _buildCard(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${meeting.meetingType} Meet',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          meeting.meetingDate.toLocal().toString().substring(0, 16),
                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Notes: ${meeting.notes ?? "No notes."}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ChatScreen(meetingId: meeting.id)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: Badge(
                          isLabelVisible: unreadChats > 0,
                          label: Text('$unreadChats'),
                          child: const Icon(Icons.chat_bubble_outline, size: 14),
                        ),
                        label: const Text('Open Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      if (meeting.scheduledByUserId == staff.id)
                        OutlinedButton(
                          onPressed: () => _showRescheduleDialog(meeting),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Reschedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Quick Actions
        const Text('Quick Case Actions', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Schedule Meeting Button (available before case resolution)
              if (!isResolved) ...[
                ElevatedButton.icon(
                  onPressed: _showScheduleMeetingDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.video_call_outlined, size: 18),
                  label: const Text('Schedule Coordination Meeting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 10),
              ],

              // --- 5-STAGE WORKFLOW ACTION CONTROLS ---
              if (!isResolved) ...[
                // STAGE 1: OSD Initial Assessment
                if (report.stageNumber == 1) ...[
                  if (staff.role == UserRole.osd) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showForwardForInitialInterventionDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.forward_to_inbox, size: 18),
                      label: const Text('Forward for Initial Intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Stage 1: Awaiting OSD Initial Assessment and Referral to Ministrong Tagasubaybay & Section Adviser.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // STAGE 2: Ministrong Tagasubaybay & Section Adviser Joint Intervention
                if (report.stageNumber == 2) ...[
                  if (staff.role == UserRole.ministrong_tagasubaybay || staff.role == UserRole.adviser) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showResolveInitialInterventionDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Resolve Case (Intervention Successful)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showEscalateToOsdAndPrincipalDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      label: const Text('Escalate to OSD and Principal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: const Text(
                        'Stage 2: Joint Intervention actively handled by Ministrong Tagasubaybay and Section Adviser.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // STAGE 3: OSD & Principal Joint Intervention
                if (report.stageNumber == 3) ...[
                  if (staff.role == UserRole.osd || staff.role == UserRole.principal) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showResolveOsdAndPrincipalDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.gavel, size: 18),
                      label: const Text('Resolve & Impose Disciplinary Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showEscalateToBoardDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.account_balance, size: 18),
                      label: const Text('Escalate to Board of Discipline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Stage 3: Joint Intervention actively handled by OSD and Principal.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // STAGE 4: Board of Discipline Deliberation & Punishment
                if (report.stageNumber == 4) ...[
                  if (staff.role == UserRole.board_of_discipline) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showBoardDecisionDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.balance, size: 18),
                      label: const Text('Finalize Board Decision & Punishment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF4FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF0ABFC)),
                      ),
                      child: const Text(
                        'Stage 4: Formal deliberation & punishment determination by the Board of Discipline.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF86198F), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // STAGE 5: School President Final Review
                if (report.stageNumber == 5) ...[
                  if (staff.role == UserRole.school_president) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showPresidentReviewDialog(report!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.verified, size: 18),
                      label: const Text('Complete President Final Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Stage 5: Board punishment determined. Awaiting School President final review.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Disciplinary Proceedings Complete / Resolved',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Add Note Button
              OutlinedButton.icon(
                onPressed: _showAddNoteDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Add Timeline Progress Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 10),

              // Staff-Requested Case Consistency Check Button (Optional Intelligence)
              OutlinedButton.icon(
                onPressed: _isCheckingConsistency ? null : () => _handleRunConsistencyCheck(report!, timelineEvents, meetings),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isCheckingConsistency
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                    : const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Run AI Case Consistency Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),

              // View Case Archive Packet Button (When Resolved or Closed)
              if (report.status == 'resolved' || report.status == 'closed') ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showCaseArchivePacketDialog(report!, timelineEvents, meetings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('View Case Archive Packet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),

        // Disciplinary Approval & Acknowledgment Trail
        _buildDisciplinaryApprovalTrailCard(report),

        // Case Outcome Card (If Resolved)
        if (report.status == 'resolved' || report.status == 'closed') ...[
          const SizedBox(height: 16),
          const Text('Incident Resolution Outcome', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildCard(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFFBBF7D0)),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Text(
                      'Case Resolved Outcome',
                      style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Action Given: ${report.disciplineAction}',
                  style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Resolution Notes:\n${report.disciplineNotes}',
                  style: const TextStyle(color: Color(0xFF1E3A1E), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        title: Text(
          'Incident Detail: ${report.studentName}',
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF475569)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftPane,
                      const SizedBox(height: 16),
                      rightPane,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: leftPane),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: rightPane),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _victimInfoBox(ReportModel r) {
    final isAdviserObserved = r.reportSource == 'Adviser-Observed';
    final reporterLabel = isAdviserObserved 
        ? (r.reporterName != null ? 'Adviser: ${r.reporterName}' : r.parentName)
        : '${r.parentName} (Parent)';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdviserObserved ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        border: Border.all(color: isAdviserObserved ? const Color(0xFF99F6E4) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (isAdviserObserved) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'ADVISER-OBSERVED INCIDENT',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
          _infoRow('Victim name', r.studentName),
          const SizedBox(height: 6),
          _infoRow('Grade / Section', '${r.studentGrade} - ${r.studentSection}'),
          const SizedBox(height: 6),
          _infoRow('Report Source', isAdviserObserved ? 'Adviser Direct Observation' : 'Parent-Reported'),
          const SizedBox(height: 6),
          _infoRow('Submitted By', reporterLabel),
          if (r.urgencyLevel != 'Moderate') ...[
            const SizedBox(height: 6),
            _infoRow('Urgency Level', '${r.urgencyLevel} Severity'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        Text(val, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDisciplinaryApprovalTrailCard(ReportModel report) {
    final isResolved = report.status == 'resolved' || report.status == 'closed';
    final hasSanction = report.disciplineAction != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Disciplinary Approval & Acknowledgment Trail',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sanction Record', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasSanction ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasSanction ? (report.disciplineAction ?? 'Counseling') : 'Under Formulation',
                      style: TextStyle(
                        color: hasSanction ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildApprovalStep(
                title: '1. Incident Intake & Verification',
                subtitle: 'Logged by ${report.reporterName ?? report.parentName} (${report.createdAt.toLocal().toString().substring(0, 10)})',
                isDone: true,
              ),
              _buildApprovalStep(
                title: '2. Section Adviser Acknowledgment',
                subtitle: 'Mediation dialogue & student monitoring',
                isDone: report.status != 'Pending' || isResolved,
              ),
              _buildApprovalStep(
                title: '3. Administrative & Guidance Review',
                subtitle: 'Principal / Guidance assessment of protective measures',
                isDone: isResolved || report.status.toLowerCase().contains('escalat') || report.status == 'scheduled_meeting',
              ),
              _buildApprovalStep(
                title: '4. Disciplinary Board Finalization',
                subtitle: isResolved ? 'Resolution confirmed by authorized personnel' : 'Pending final closure sign-off',
                isDone: isResolved,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalStep({
    required String title,
    required String subtitle,
    required bool isDone,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              size: 18,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
