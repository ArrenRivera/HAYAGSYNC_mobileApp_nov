class ReportModel {
  final String id;
  final String parentId;
  final String parentName;
  final String studentName;
  final String studentSection;
  final String studentGrade;
  final String title;
  final String description;
  final String category;
  final DateTime incidentDate;
  final String incidentLocation;
  final String? evidenceUrl;
  final String evidenceVerificationState; // 'Verified', 'Suspected AI Generated', 'Suspected Google Image', 'Unverified'
  final String? evidenceVerificationDetails;
  final String? aiSummary;
  final String status; // 'Pending', 'Under Review', 'Scheduled', 'Escalated', 'Resolved'
  final String? disciplineAction; // 'Warning', 'Counseling', 'Mediation', 'Suspension', 'Other'
  final String? disciplineNotes;
  final String? appealedReason;
  final int appealCount;
  final DateTime createdAt;
  final String? bullyName;
  final String? bullyGradeSection;
  final List<String>? witnesses;
  final String reportSource; // 'Parent-Reported', 'Adviser-Observed'
  final String? reporterId;
  final String? reporterName;
  final String urgencyLevel; // 'Low', 'Moderate', 'High'
  final String? escalationReason;
  final String? escalationNotes;
  final String? escalatedTo;
  final String? boardFindings;
  final String? boardDecision;
  final String? punishmentImposed;
  final String? presidentNotes;

  ReportModel({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.studentName,
    required this.studentSection,
    required this.studentGrade,
    required this.title,
    required this.description,
    required this.category,
    required this.incidentDate,
    required this.incidentLocation,
    this.evidenceUrl,
    required this.evidenceVerificationState,
    this.evidenceVerificationDetails,
    this.aiSummary,
    required this.status,
    this.disciplineAction,
    this.disciplineNotes,
    this.appealedReason,
    this.appealCount = 0,
    required this.createdAt,
    this.bullyName,
    this.bullyGradeSection,
    this.witnesses,
    this.reportSource = 'Parent-Reported',
    this.reporterId,
    this.reporterName,
    this.urgencyLevel = 'Moderate',
    this.escalationReason,
    this.escalationNotes,
    this.escalatedTo,
    this.boardFindings,
    this.boardDecision,
    this.punishmentImposed,
    this.presidentNotes,
  });

  bool get isAnonymous =>
      reportSource.toLowerCase().contains('anonymous') ||
      parentName.toLowerCase().contains('anonymous') ||
      (reporterName != null && reporterName!.toLowerCase().contains('anonymous'));

  int get stageNumber {
    final s = status.toLowerCase();
    if (s.contains('president') || s.contains('finalized')) return 5;
    if (s.contains('board')) return 4;
    if (s.contains('osd and principal') || s == 'escalated to osd') return 3;
    if (s.contains('initial intervention') ||
        s.contains('ministro') ||
        s.contains('scheduled') ||
        s.contains('under review') ||
        s == 'escalated to principal' ||
        s == 'escalated') {
      return 2;
    }
    if (s.contains('resolved') || s.contains('closed')) return 5;
    return 1; // Stage 1: OSD Initial Assessment (Pending, Recent Report, etc.)
  }

  String get stageName {
    final s = status.toLowerCase();
    if (s.contains('resolved') || s.contains('closed')) return 'Resolved / Closed';
    switch (stageNumber) {
      case 1:
        return 'Stage 1: OSD Initial Assessment';
      case 2:
        return 'Stage 2: Ministrong Tagasubaybay & Adviser';
      case 3:
        return 'Stage 3: OSD & Principal Joint Intervention';
      case 4:
        return 'Stage 4: Board of Discipline Deliberation';
      case 5:
        return 'Stage 5: School President Final Review';
      default:
        return 'Stage 1: OSD Initial Assessment';
    }
  }

  String get currentHandlingOffice {
    final s = status.toLowerCase();
    if (s.contains('resolved') || s.contains('closed')) return 'Resolved (Closed)';
    switch (stageNumber) {
      case 1:
        return 'OSD (Initial Assessment)';
      case 2:
        return 'Ministrong Tagasubaybay & Section Adviser';
      case 3:
        return 'OSD & Principal';
      case 4:
        return 'Board of Discipline';
      case 5:
        return 'School President';
      default:
        return 'OSD (Initial Assessment)';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'parentName': parentName,
      'studentName': studentName,
      'studentSection': studentSection,
      'studentGrade': studentGrade,
      'title': title,
      'description': description,
      'category': category,
      'incidentDate': incidentDate.toIso8601String(),
      'incidentLocation': incidentLocation,
      'evidenceUrl': evidenceUrl,
      'evidenceVerificationState': evidenceVerificationState,
      'evidenceVerificationDetails': evidenceVerificationDetails,
      'aiSummary': aiSummary,
      'status': status,
      'disciplineAction': disciplineAction,
      'disciplineNotes': disciplineNotes,
      'appealedReason': appealedReason,
      'appealCount': appealCount,
      'createdAt': createdAt.toIso8601String(),
      'bully_name': bullyName,
      'bully_grade_section': bullyGradeSection,
      'witnesses': witnesses,
      'report_source': reportSource,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'urgency_level': urgencyLevel,
      'escalation_reason': escalationReason,
      'escalation_notes': escalationNotes,
      'escalated_to': escalatedTo,
      'board_findings': boardFindings,
      'board_decision': boardDecision,
      'punishment_imposed': punishmentImposed,
      'president_notes': presidentNotes,
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id']?.toString() ?? '',
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString() ?? '',
      parentName: json['parentName'] ?? json['parent_name'] ?? '',
      studentName: json['studentName'] ?? json['student_name'] ?? '',
      studentSection: json['studentSection'] ?? json['student_section'] ?? '',
      studentGrade: json['studentGrade'] ?? json['student_grade'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      incidentDate: DateTime.parse(json['incidentDate'] ?? json['incident_date'] ?? DateTime.now().toIso8601String()),
      incidentLocation: json['incidentLocation'] ?? json['incident_location'] ?? '',
      evidenceUrl: json['evidenceUrl'] ?? json['evidence_url'],
      evidenceVerificationState: json['evidenceVerificationState'] ?? json['evidence_verification_state'] ?? 'Unverified',
      evidenceVerificationDetails: json['evidenceVerificationDetails'] ?? json['evidence_verification_details'],
      aiSummary: json['aiSummary'] ?? json['ai_summary'],
      status: json['status'] ?? 'Pending',
      disciplineAction: json['disciplineAction'] ?? json['discipline_action'],
      disciplineNotes: json['disciplineNotes'] ?? json['discipline_notes'],
      appealedReason: json['appealedReason'] ?? json['appealed_reason'],
      appealCount: json['appealCount'] ?? json['appeal_count'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      bullyName: json['bully_name'] ?? json['bullyName'],
      bullyGradeSection: json['bully_grade_section'] ?? json['bullyGradeSection'],
      witnesses: json['witnesses'] != null ? List<String>.from(json['witnesses']) : null,
      reportSource: json['report_source'] ?? json['reportSource'] ?? 'Parent-Reported',
      reporterId: json['reporter_id']?.toString() ?? json['reporterId']?.toString(),
      reporterName: json['reporter_name'] ?? json['reporterName'],
      urgencyLevel: json['urgency_level'] ?? json['urgencyLevel'] ?? 'Moderate',
      escalationReason: json['escalation_reason'] ?? json['escalationReason'],
      escalationNotes: json['escalation_notes'] ?? json['escalationNotes'],
      escalatedTo: json['escalated_to'] ?? json['escalatedTo'],
      boardFindings: json['board_findings'] ?? json['boardFindings'],
      boardDecision: json['board_decision'] ?? json['boardDecision'],
      punishmentImposed: json['punishment_imposed'] ?? json['punishmentImposed'],
      presidentNotes: json['president_notes'] ?? json['presidentNotes'],
    );
  }

  ReportModel copyWith({
    String? status,
    String? aiSummary,
    String? evidenceVerificationState,
    String? evidenceVerificationDetails,
    String? disciplineAction,
    String? disciplineNotes,
    String? appealedReason,
    int? appealCount,
    String? bullyName,
    String? bullyGradeSection,
    List<String>? witnesses,
    String? reportSource,
    String? reporterId,
    String? reporterName,
    String? urgencyLevel,
    String? escalationReason,
    String? escalationNotes,
    String? escalatedTo,
    String? boardFindings,
    String? boardDecision,
    String? punishmentImposed,
    String? presidentNotes,
  }) {
    return ReportModel(
      id: id,
      parentId: parentId,
      parentName: parentName,
      studentName: studentName,
      studentSection: studentSection,
      studentGrade: studentGrade,
      title: title,
      description: description,
      category: category,
      incidentDate: incidentDate,
      incidentLocation: incidentLocation,
      evidenceUrl: evidenceUrl,
      evidenceVerificationState: evidenceVerificationState ?? this.evidenceVerificationState,
      evidenceVerificationDetails: evidenceVerificationDetails ?? this.evidenceVerificationDetails,
      aiSummary: aiSummary ?? this.aiSummary,
      status: status ?? this.status,
      disciplineAction: disciplineAction ?? this.disciplineAction,
      disciplineNotes: disciplineNotes ?? this.disciplineNotes,
      appealedReason: appealedReason ?? this.appealedReason,
      appealCount: appealCount ?? this.appealCount,
      createdAt: createdAt,
      bullyName: bullyName ?? this.bullyName,
      bullyGradeSection: bullyGradeSection ?? this.bullyGradeSection,
      witnesses: witnesses ?? this.witnesses,
      reportSource: reportSource ?? this.reportSource,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      escalationReason: escalationReason ?? this.escalationReason,
      escalationNotes: escalationNotes ?? this.escalationNotes,
      escalatedTo: escalatedTo ?? this.escalatedTo,
      boardFindings: boardFindings ?? this.boardFindings,
      boardDecision: boardDecision ?? this.boardDecision,
      punishmentImposed: punishmentImposed ?? this.punishmentImposed,
      presidentNotes: presidentNotes ?? this.presidentNotes,
    );
  }
}
