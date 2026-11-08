import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/report_model.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/timeline_widget.dart';
import '../../widgets/evidence_media_widget.dart';
import '../chat/chat_screen.dart';

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _db = DatabaseService();

  final List<SelectedMedia> _reAppealMediaList = [];
  final _reAppealReasonController = TextEditingController();
  final _reAppealCommentsController = TextEditingController();
  bool _isSubmittingReAppeal = false;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbUpdate);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbUpdate);
    _reAppealReasonController.dispose();
    _reAppealCommentsController.dispose();
    super.dispose();
  }

  void _onDbUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ReportModel? report;
    try {
      report = _db.getReportById(widget.reportId);
    } catch (_) {
      report = null;
    }

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case Details')),
        body: const Center(
          child: Text(
            'Unauthorized access or report not found.',
            style: TextStyle(color: Color(0xFF0F172A)),
          ),
        ),
      );
    }

    final meetings = _db.getMeetingsForReport(report.id);
    final timelineEvents = _db.getTimelineEvents(report.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Case Ref: ${report.id.substring(0, min(report.id.length, 8)).toUpperCase()}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
                // DepEd Child Protection Safeguard Notice
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'DepEd Child Protection Safeguard (D.O. 40, s. 2012): Bullying allegations are officially subject to school inquiry and counseling. Personal privacy and confidential disciplinary records of non-involved parties are protected under the Data Privacy Act.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top overview Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge(status: report.status),
                            if (report.appealCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFCA5A5),
                                  ),
                                ),
                                child: Text(
                                  'APPEALED x${report.appealCount}',
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          report.title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _metaRow(
                          Icons.person_outline,
                          'Student Subject (Victim)',
                          '${report.studentName} (${report.studentSection})',
                        ),
                        const SizedBox(height: 8),
                        _metaRow(
                          Icons.warning_amber_outlined,
                          'Reported Bully / Offender',
                          report.bullyName != null
                              ? '${report.bullyName!} (${report.bullyGradeSection ?? ""})'
                              : 'Not specified',
                        ),
                        const SizedBox(height: 8),
                        _metaRow(
                          Icons.category_outlined,
                          'Category',
                          report.category,
                        ),
                        const SizedBox(height: 8),
                        _metaRow(
                          Icons.location_on_outlined,
                          'Location',
                          report.incidentLocation,
                        ),
                        const SizedBox(height: 8),
                        _metaRow(
                          Icons.calendar_today_outlined,
                          'Incident Date',
                          report.incidentDate.toLocal().toString().substring(
                            0,
                            16,
                          ),
                        ),
                        if (report.reportSource == 'Adviser-Observed') ...[
                          const SizedBox(height: 8),
                          _metaRow(
                            Icons.badge_outlined,
                            'Report Filed By',
                            'Adviser: ${report.reporterName ?? "Section Faculty"}',
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        const Text(
                          'Incident Description:',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.description,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Escalation History & Investigation Progress
                if (report.status.toLowerCase().contains('escalat') ||
                    report.escalatedTo != null) ...[
                  const Text(
                    'Investigation Progress & Escalation',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFFFFFBEB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_outlined,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Stage: ${report.status}',
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (report.escalatedTo != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Assigned Authority: ${report.escalatedTo}',
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (report.escalationReason != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason for Escalation: ${report.escalationReason}',
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (report.escalationNotes != null &&
                              report.escalationNotes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notes: ${report.escalationNotes}',
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Involved Students Section (Victim & Alleged Bully)
                const Text(
                  'Involved Students (Biktima at Alleged Offender)',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // 1. Prominent Victim Card
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'REPORTED VICTIM / SUBJECT',
                                        style: TextStyle(
                                          color: Color(0xFF1D4ED8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: const Text(
                                          'Biktima',
                                          style: TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.studentName.isNotEmpty
                                        ? report.studentName
                                        : 'Student',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${report.studentGrade.isNotEmpty ? "${report.studentGrade} · " : ""}${report.studentSection}',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
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

                // 2. Prominent Bully & Witnesses Card
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'REPORTED BULLY / ALLEGED OFFENDER',
                                        style: TextStyle(
                                          color: Color(0xFFB45309),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: const Text(
                                          'Inquiry',
                                          style: TextStyle(
                                            color: Color(0xFFB45309),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.bullyName != null &&
                                            report.bullyName!.isNotEmpty
                                        ? report.bullyName!
                                        : 'Not explicitly named in report',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (report.bullyGradeSection != null &&
                                      report.bullyGradeSection!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      report.bullyGradeSection!,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (report.witnesses != null &&
                            report.witnesses!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(color: Color(0xFFFDE68A)),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                color: Color(0xFFB45309),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Witnesses: ',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.witnesses!.join(', '),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Meetings Card
                if (meetings.isNotEmpty) ...[
                  const Text(
                    'Meeting Schedules',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...meetings.map((meeting) {
                    final unreadChats = _db.getUnreadMessageCount(meeting.id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.video_call_outlined,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      meeting.meetingType == 'parent_meeting'
                                          ? 'Parent-Staff Meeting'
                                          : 'Student Counseling',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Text(
                                    meeting.meetingDate
                                        .toLocal()
                                        .toString()
                                        .substring(0, 16),
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Notes: ${meeting.notes ?? "No notes."}',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Scheduled By:',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      '${meeting.scheduledByUserName} (${meeting.scheduledByUserRole.toUpperCase()})',
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatScreen(meetingId: meeting.id),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: Badge(
                                    isLabelVisible: unreadChats > 0,
                                    label: Text('$unreadChats'),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                    ),
                                  ),
                                  label: const Text(
                                    'Chat regarding schedule',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // Disciplinary Outcomes (If officially recorded or Resolved)
                if (report.status.toLowerCase() == 'resolved' ||
                    report.status.toLowerCase() == 'closed' ||
                    report.disciplineAction != null ||
                    report.disciplineNotes != null) ...[
                  const Text(
                    'Disciplinary Measures & Actions Taken',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.gavel_outlined,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Disciplinary Action Administered',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: Text(
                                  report.disciplineAction?.toUpperCase() ??
                                      'COUNSELING',
                                  style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Official Action Notes:',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.disciplineNotes ??
                                'Inquiry and guidance counseling in progress.',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          if (report.status.toLowerCase() == 'resolved' ||
                              report.status.toLowerCase() == 'closed') ...[
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            const Text(
                              'If you disagree with this resolution outcome, you can appeal the case to reopen the investigation.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showReAppealSheet(report!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.replay_outlined, size: 18),
                              label: const Text(
                                'Re-Appeal Resolved Case',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Evidence Details Card
                if (report.evidenceUrl != null) ...[
                  const Text(
                    'Evidence Scan Report',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.document_scanner_outlined,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  report.evidenceUrl!,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      report.evidenceVerificationState ==
                                          'Verified'
                                      ? const Color(0xFFF0FDF4)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        report.evidenceVerificationState ==
                                            'Verified'
                                        ? const Color(0xFFBBF7D0)
                                        : const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  report.evidenceVerificationState
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        report.evidenceVerificationState ==
                                            'Verified'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (report.evidenceVerificationDetails != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              report.evidenceVerificationDetails!,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                          EvidenceMediaWidget(filename: report.evidenceUrl!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Timeline Widget
                const Text(
                  'Case Activity & Timeline Logs',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TimelineWidget(events: timelineEvents),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int min(int a, int b) => a < b ? a : b;

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

  Future<void> _startUploadReAppeal(
    SelectedMedia media,
    StateSetter setModalState,
  ) async {
    setModalState(() {
      media.uploadProgress = 0.0;
    });
    setState(() {});

    final url = await _uploadFile(media.file, (progress) {
      setModalState(() {
        media.uploadProgress = progress;
      });
      setState(() {});
    });

    setModalState(() {
      if (url != null) {
        media.uploadedUrl = url;
        media.uploadProgress = 1.0;
      } else {
        media.uploadProgress = -2.0;
      }
    });
    setState(() {});
  }

  Future<void> _pickFileReAppeal(StateSetter setModalState) async {
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
          setModalState(() {
            _reAppealMediaList.add(media);
          });
          setState(() {});
          _startUploadReAppeal(media, setModalState);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
    }
  }

  void _removeMediaReAppeal(int index, StateSetter setModalState) {
    setModalState(() {
      _reAppealMediaList.removeAt(index);
    });
    setState(() {});
  }

  void _showReAppealSheet(ReportModel report) {
    _reAppealMediaList.clear();
    _reAppealReasonController.clear();
    _reAppealCommentsController.clear();
    _isSubmittingReAppeal = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Re-Appeal Resolved Case',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please state the reason and details for reopening this case. This request will be submitted to the assigned section Adviser, Principal, Ministrong Tagasubaybay, and OSD officers for immediate review.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reason Field
                      const Text(
                        'Reason for Re-Appeal (Required)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reAppealReasonController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'e.g., The issue has recurred, or new evidence has surfaced...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Comments Field
                      const Text(
                        'Additional Explanation / Comments (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reAppealCommentsController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Provide a detailed explanation...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Evidence Upload Section
                      const Text(
                        'Attach New Evidence (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select photos or videos to support your re-appeal. Files will be uploaded securely.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _pickFileReAppeal(setModalState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.upload_file_outlined,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                        label: const Text(
                          'Choose File from Device',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      if (_reAppealMediaList.isNotEmpty) ...[
                        const SizedBox(height: 16),
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
                          itemCount: _reAppealMediaList.length,
                          itemBuilder: (context, index) {
                            final media = _reAppealMediaList[index];
                            final isVideo =
                                media.file.name.toLowerCase().endsWith(
                                  '.mp4',
                                ) ||
                                media.file.name.toLowerCase().endsWith('.mov');

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
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
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
                                            GestureDetector(
                                              onTap: () => _startUploadReAppeal(
                                                media,
                                                setModalState,
                                              ),
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
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Retry',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Delete button
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeMediaReAppeal(
                                        index,
                                        setModalState,
                                      ),
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
                      ],
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSubmittingReAppeal
                            ? null
                            : () async {
                                if (_reAppealReasonController.text
                                    .trim()
                                    .isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please state a reason for the re-appeal.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final hasOngoingUploads = _reAppealMediaList
                                    .any(
                                      (m) =>
                                          m.uploadProgress >= 0.0 &&
                                          m.uploadProgress < 1.0,
                                    );
                                if (hasOngoingUploads) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please wait for all uploads to complete.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final hasFailedUploads = _reAppealMediaList.any(
                                  (m) => m.uploadProgress == -2.0,
                                );
                                if (hasFailedUploads) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please remove or retry failed file uploads.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  _isSubmittingReAppeal = true;
                                });
                                setState(() {});

                                try {
                                  final newEvidenceUrls = _reAppealMediaList
                                      .map((m) => m.uploadedUrl)
                                      .where((u) => u != null)
                                      .join(',');

                                  await _db.reAppealReport(
                                    reportId: report.id,
                                    reason: _reAppealReasonController.text
                                        .trim(),
                                    comments:
                                        _reAppealCommentsController.text
                                            .trim()
                                            .isEmpty
                                        ? null
                                        : _reAppealCommentsController.text
                                              .trim(),
                                    newEvidenceUrl: newEvidenceUrls.isEmpty
                                        ? null
                                        : newEvidenceUrls,
                                  );

                                  if (!mounted) return;
                                  Navigator.of(
                                    context,
                                  ).pop(); // close bottom sheet
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Re-Appeal submitted successfully!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Re-Appeal failed: $e'),
                                    ),
                                  );
                                } finally {
                                  setModalState(() {
                                    _isSubmittingReAppeal = false;
                                  });
                                  setState(() {});
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmittingReAppeal
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
                                  Text('Submitting Re-Appeal...'),
                                ],
                              )
                            : const Text(
                                'Submit Re-Appeal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- HELPER CLASSES ---

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
