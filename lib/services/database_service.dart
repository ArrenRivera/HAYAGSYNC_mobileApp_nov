import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/report_model.dart';
import '../models/meeting_model.dart';
import '../models/chat_model.dart';
import '../models/timeline_model.dart';

class DatabaseService extends ChangeNotifier {
  // Singleton Pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    _startRealtimeSync();
  }

  // Supabase Base URL
  static String baseUrl = 'https://zrttfhtmylwbrbvvgfpg.supabase.co';

  // Supabase Client
  SupabaseClient get _supabase => Supabase.instance.client;

  static const String evidenceBucket = 'hayagsync-evidence';

  Future<String> uploadEvidence({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    final profileId = int.tryParse(_currentUser?.id ?? '');
    if (profileId == null || _supabase.auth.currentUser == null) {
      throw Exception('Please sign in before uploading evidence.');
    }
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final objectPath =
        '$profileId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _supabase.storage
        .from(evidenceBucket)
        .uploadBinary(
          objectPath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return objectPath;
  }

  Future<String> getEvidenceSignedUrl(String objectPath) =>
      _supabase.storage.from(evidenceBucket).createSignedUrl(objectPath, 3600);

  Future<bool> hasAcceptedTerms(String profileId) async {
    final row = await _supabase
        .from('user_consents')
        .select('id')
        .eq('user_id', int.parse(profileId))
        .eq('consent_version', 'v3')
        .maybeSingle();
    return row != null;
  }

  Future<void> recordTermsAcceptance(String profileId) async {
    await _supabase.from('user_consents').upsert({
      'user_id': int.parse(profileId),
      'consent_version': 'v3',
    }, onConflict: 'user_id,consent_version');
  }

  Future<void> clearTermsAcceptance(String profileId) async {
    await _supabase
        .from('user_consents')
        .delete()
        .eq('user_id', int.parse(profileId))
        .eq('consent_version', 'v3');
  }

  Future<void> saveAiSummary({
    required String period,
    required String summary,
    required Map<String, dynamic> stats,
    String? scopeId,
  }) async {
    await _supabase.from('ai_summaries').insert({
      'period': period,
      'scope_id': scopeId,
      'summary_text': summary,
      'stats': stats,
    });
  }

  String? _token;
  String? get token => _token;
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  StudentModel? _selectedChild;
  StudentModel? get selectedChild => _selectedChild;

  Timer? _realtimeTimer;

  void _startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentUser != null) {
        syncData();
      }
    });
  }

  void selectChild(StudentModel? child) {
    _selectedChild = child;
    notifyListeners();
  }

  // Local Memory Cache for UI synchronizations
  final Map<String, UserModel> _users = {};
  final List<ReportModel> _reports = [];
  final List<MeetingModel> _meetings = [];
  final List<ChatMessage> _messages = [];
  final List<TimelineEvent> _timelines = [];
  final List<StudentModel> _students = [];

  List<ReportModel> get reports => List.unmodifiable(getReports());
  List<MeetingModel> get meetings => List.unmodifiable(_meetings);
  List<StudentModel> get students => List.unmodifiable(getStudents());

  static bool isSectionMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final normA = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normB = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normA == normB) return true;
    return normA.contains(normB) || normB.contains(normA);
  }

  // Automatic Grade-Level Assignments Helper
  static Map<String, dynamic> determineGradeAssignments({
    required String studentGrade,
    required String studentSection,
    String? bullyGradeSection,
  }) {
    final List<String> grades = [];
    for (final text in [
      studentGrade,
      studentSection,
      bullyGradeSection ?? '',
    ]) {
      final match = RegExp(
        r'Grade\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final g = 'Grade ${match.group(1)}';
        if (!grades.contains(g)) grades.add(g);
      }
    }
    if (grades.isEmpty) {
      grades.add('Grade 7');
    }

    final Map<String, String> ministroMap = {
      'Grade 7': 'Gng. Corazon Alcantara (ministro.grade7@hayag.edu.ph)',
      'Grade 8': 'G. Arnel Bautista (ministro.grade8@hayag.edu.ph)',
      'Grade 9': 'Gng. Remedios Santos (ministro.grade9@hayag.edu.ph)',
      'Grade 10': 'G. Danilo Cruz (ministro.grade10@hayag.edu.ph)',
      'Grade 11': 'Gng. Jocelyn Reyes (ministro.grade11@hayag.edu.ph)',
      'Grade 12': 'G. Fernando Garcia (ministro.grade12@hayag.edu.ph)',
    };

    final Map<String, String> osdMap = {
      'Grade 7': 'G. Renato Dalisay (osd.grade7@hayag.edu.ph)',
      'Grade 8': 'Gng. Teresa Mercado (osd.grade8@hayag.edu.ph)',
      'Grade 9': 'G. Victor Navarro (osd.grade9@hayag.edu.ph)',
      'Grade 10': 'Gng. Angela Pineda (osd.grade10@hayag.edu.ph)',
      'Grade 11': 'G. Marco Valenzuela (osd.grade11@hayag.edu.ph)',
      'Grade 12': 'Gng. Caridad Soriano (osd.grade12@hayag.edu.ph)',
    };

    final assignedMinistros = grades
        .map((g) => ministroMap[g] ?? 'Ministrong Tagasubaybay ($g)')
        .toList();
    final assignedOsds = grades
        .map((g) => osdMap[g] ?? 'OSD Officer ($g)')
        .toList();

    final hasJhs = grades.any(
      (g) => ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'].contains(g),
    );
    final hasShs = grades.any((g) => ['Grade 11', 'Grade 12'].contains(g));

    final List<String> assignedPrincipals = [];
    if (hasJhs) {
      assignedPrincipals.add(
        'Dr. Alicia Magalong (JHS Principal, Grades 7–10)',
      );
    }
    if (hasShs) {
      assignedPrincipals.add(
        'Dr. Evelyn Morales (SHS Principal, Grades 11–12)',
      );
    }

    return {
      'grades': grades,
      'primaryGrade': grades.first,
      'ministros': assignedMinistros,
      'osds': assignedOsds,
      'principals': assignedPrincipals,
      'ministroName': assignedMinistros.join(' & '),
      'osdName': assignedOsds.join(' & '),
      'principalName': assignedPrincipals.join(' & '),
    };
  }

  List<String>? _parseWitnesses(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.startsWith('[')) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return null;
  }

  // --- REFRESH CACHE FROM SUPABASE ---

  Future<void> syncData() async {
    if (_currentUser == null) return;
    try {
      // 1. Fetch Reports: All four initial handling roles (and Board/President) have access to ALL submitted reports
      dynamic reportsRes;
      try {
        reportsRes = await _supabase
            .from('reports')
            .select()
            .order('id', ascending: false);
      } catch (err) {
        debugPrint('Reports fetch error: $err');
        return;
      }

      _reports.clear();
      for (var item in reportsRes) {
        final repSec = item['student_section']?.toString() ?? '';
        final isAnon =
            (item['parent_name']?.toString().toLowerCase().contains(
                  'anonymous',
                ) ??
                false) ||
            (item['report_source']?.toString().toLowerCase().contains(
                  'anonymous',
                ) ??
                false);

        _reports.add(
          ReportModel(
            id: item['id'].toString(),
            parentId: item['parent_id']?.toString() ?? '',
            parentName: isAnon
                ? 'Anonymous Reporter'
                : (item['parent_name'] ?? 'Parent'),
            studentName: item['student_name'] ?? 'Student',
            studentSection: repSec,
            studentGrade: item['student_grade'] ?? '',
            title: item['title'] ?? '',
            description: item['description'] ?? '',
            category: item['category'] ?? '',
            incidentDate: DateTime.parse(
              item['incident_date'] ?? DateTime.now().toIso8601String(),
            ),
            incidentLocation: item['incident_location'] ?? '',
            evidenceUrl: item['evidence_url'],
            evidenceVerificationState:
                item['evidence_verification_state'] ?? 'Unverified',
            evidenceVerificationDetails: item['evidence_verification_details'],
            aiSummary: item['ai_summary'],
            status: item['status'] ?? 'Pending',
            disciplineAction: item['discipline_action'],
            disciplineNotes: item['discipline_notes'],
            appealedReason: item['appealed_reason'],
            appealCount: item['appeal_count'] ?? 0,
            createdAt: DateTime.parse(
              item['created_at'] ?? DateTime.now().toIso8601String(),
            ),
            bullyName: item['bully_name'],
            bullyGradeSection: item['bully_grade_section'],
            witnesses: _parseWitnesses(item['witnesses']),
            reportSource: isAnon
                ? 'Anonymous'
                : (item['report_source'] ?? 'Parent-Reported'),
            reporterId: item['reporter_id']?.toString(),
            reporterName: isAnon ? 'Anonymous Reporter' : item['reporter_name'],
            urgencyLevel: item['urgency_level'] ?? 'Moderate',
            escalationReason: item['escalation_reason'],
            escalationNotes: item['escalation_notes'],
            escalatedTo: item['escalated_to'],
          ),
        );
      }

      // 2. Fetch Students from database
      _students.clear();
      final studentsRes = await _supabase
          .from('students')
          .select()
          .order('name');

      for (var item in studentsRes) {
        _students.add(StudentModel.fromJson(item));
      }

      // 3. Fetch Directory if Staff
      if (_currentUser != null && _currentUser!.role != UserRole.parent) {
        final dirRes = await _supabase
            .from('users')
            .select(
              'id, auth_user_id, email, name, role, avatar_url, assigned_section, student_name, student_grade, student_section, academic_year, created_at, updated_at, students(*)',
            )
            .eq('role', 'parent');

        _users.clear();
        for (var item in dirRes) {
          final u = UserModel.fromJson(item);
          _users[u.id] = u;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  // --- AUTH ENDPOINTS ---

  Future<UserModel> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
    try {
      final profile = await _loadCurrentProfile();
      await logLoginAttempt(
        userId: profile.id,
        email: cleanEmail,
        success: true,
      );
      await syncData();
      return profile;
    } catch (_) {
      await _supabase.auth.signOut();
      throw Exception(
        'Walang HayagSync profile ang account na ito. Makipag-ugnayan sa administrator.',
      );
    }
  }

  Future<UserModel> registerParent({
    required String name,
    required String email,
    required String password,
    required String studentName,
    required String sectionName,
    required String gradeLevel,
    required String academicYear,
    required String certificateFilename,
    List<Map<String, String>> verifiedChildren = const [],
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final initialStudents = verifiedChildren.isNotEmpty
        ? verifiedChildren
        : (studentName.trim().isEmpty
              ? <Map<String, String>>[]
              : [
                  {
                    'studentName': studentName.trim(),
                    'gradeLevel': gradeLevel,
                    'sectionName': sectionName,
                    'academicYear': academicYear,
                  },
                ]);
    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'name': name.trim(), 'initial_students': initialStudents},
      );
      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Hindi nakagawa ng Supabase Auth account.');
      }
      if (response.session == null) {
        return UserModel(
          id: authUser.id,
          email: cleanEmail,
          name: name.trim(),
          role: UserRole.parent,
          studentName: initialStudents.isEmpty
              ? null
              : initialStudents.first['studentName'],
          studentGrade: initialStudents.isEmpty
              ? null
              : initialStudents.first['gradeLevel'],
          studentSection: initialStudents.isEmpty
              ? null
              : initialStudents.first['sectionName'],
          academicYear: initialStudents.isEmpty
              ? null
              : initialStudents.first['academicYear'],
        );
      }
      final profile = await _loadCurrentProfile();
      await syncData();
      return profile;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<UserModel> _loadCurrentProfile() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw Exception('Not authenticated.');
    final profile = await _supabase
        .from('users')
        .select(
          'id, auth_user_id, email, name, role, avatar_url, assigned_section, student_name, student_grade, student_section, academic_year, created_at, updated_at, students(*)',
        )
        .eq('auth_user_id', authUser.id)
        .single();
    if (profile['role'] == 'adviser' &&
        (profile['assigned_section'] == null ||
            profile['assigned_section'].toString().isEmpty)) {
      try {
        final assignment = await _supabase
            .from('staff_section_assignments')
            .select('sections(full_section_name, name, grade_level)')
            .eq('staff_id', profile['id'])
            .eq('is_active', true)
            .maybeSingle();
        final section = assignment?['sections'];
        if (section != null) {
          profile['assigned_section'] =
              section['full_section_name'] ?? section['name'];
        }
      } catch (_) {}
    }
    _token = _supabase.auth.currentSession?.accessToken;
    _currentUser = UserModel.fromJson(profile);
    _selectedChild = _currentUser!.students?.isNotEmpty == true
        ? _currentUser!.students!.first
        : null;
    notifyListeners();
    return _currentUser!;
  }

  Future<UserModel?> restoreSession() async {
    if (_supabase.auth.currentSession == null) return null;
    try {
      final profile = await _loadCurrentProfile();
      await syncData();
      return profile;
    } catch (_) {
      await _supabase.auth.signOut();
      _token = null;
      _currentUser = null;
      _selectedChild = null;
      return null;
    }
  }

  void logout() {
    unawaited(_supabase.auth.signOut());
    _token = null;
    _currentUser = null;
    _reports.clear();
    _meetings.clear();
    _messages.clear();
    _timelines.clear();
    _users.clear();
    _students.clear();
    notifyListeners();
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_currentUser == null) throw Exception('Not authenticated.');
    final email = _supabase.auth.currentUser?.email;
    if (email == null) throw Exception('No authenticated email is available.');
    await _supabase.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> updateProfilePicture(String avatarUrl) async {
    if (_currentUser == null) throw Exception('Not authenticated.');
    await _supabase
        .from('users')
        .update({'avatar_url': avatarUrl})
        .eq('auth_user_id', _supabase.auth.currentUser!.id);
    _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
    notifyListeners();
  }

  // --- REPORTING LIFECYCLE ---

  List<ReportModel> getReports() {
    if (_currentUser?.role == UserRole.parent) {
      final myId = _currentUser!.id;
      final childNames = <String>[];
      if (_currentUser?.studentName != null &&
          _currentUser!.studentName!.isNotEmpty) {
        childNames.add(_currentUser!.studentName!.toLowerCase());
      }
      if (_currentUser?.students != null) {
        for (var s in _currentUser!.students!) {
          childNames.add(s.name.toLowerCase());
        }
      }
      return _reports.where((r) {
        if (r.parentId == myId) return true;
        final st = r.studentName.toLowerCase();
        final bu = (r.bullyName ?? '').toLowerCase();
        for (var c in childNames) {
          if (c.isNotEmpty && (st.contains(c) || bu.contains(c))) return true;
        }
        return false;
      }).toList();
    }
    // All four initial handling roles (Adviser, Ministrong, OSD, Principal) + Board + President have access to ALL submitted reports
    return _reports;
  }

  ReportModel? getReportById(String id) {
    try {
      final rep = _reports.firstWhere((r) => r.id == id);
      return rep;
    } catch (_) {
      return null;
    }
  }

  List<StudentModel> getStudents({String? section}) {
    if (_currentUser?.role == UserRole.adviser &&
        _currentUser?.assignedSection != null &&
        _currentUser!.assignedSection!.isNotEmpty) {
      return _students
          .where(
            (s) => isSectionMatch(s.section, _currentUser!.assignedSection!),
          )
          .toList();
    }
    if (section != null && section.isNotEmpty) {
      return _students
          .where((s) => isSectionMatch(s.section, section))
          .toList();
    }
    return _students;
  }

  Future<ReportModel> submitReport({
    required String title,
    required String description,
    required String category,
    required DateTime incidentDate,
    required String incidentLocation,
    String? evidenceUrl,
    required String evidenceVerificationState,
    String? evidenceVerificationDetails,
    String? aiSummary,
    String? bullyName,
    String? bullyGradeSection,
    List<String>? witnesses,
    String? studentId,
  }) async {
    final repData = {
      'parent_id': _currentUser?.role == UserRole.parent
          ? int.tryParse(_currentUser!.id)
          : null,
      'parent_name': _currentUser?.name ?? 'Parent',
      'student_id': studentId != null ? int.tryParse(studentId) : null,
      'student_name':
          _selectedChild?.name ?? _currentUser?.studentName ?? 'Student',
      'student_grade':
          _selectedChild?.grade ?? _currentUser?.studentGrade ?? '',
      'student_section':
          _selectedChild?.section ?? _currentUser?.studentSection ?? '',
      'title': title,
      'description': description,
      'category': category,
      'incident_date': incidentDate.toIso8601String(),
      'incident_location': incidentLocation,
      'evidence_url': evidenceUrl,
      'evidence_verification_state': evidenceVerificationState,
      'evidence_verification_details': evidenceVerificationDetails,
      'ai_summary': aiSummary,
      'status': 'Pending',
      'bully_name': bullyName,
      'bully_grade_section': bullyGradeSection,
      'witnesses': witnesses != null ? json.encode(witnesses) : null,
    };

    final item = await _supabase
        .from('reports')
        .insert(repData)
        .select()
        .single();

    final newReport = ReportModel(
      id: item['id'].toString(),
      parentId: item['parent_id']?.toString() ?? '',
      parentName: item['parent_name'] ?? 'Parent',
      studentName: item['student_name'] ?? 'Student',
      studentSection: item['student_section'] ?? '',
      studentGrade: item['student_grade'] ?? '',
      title: item['title'] ?? '',
      description: item['description'] ?? '',
      category: item['category'] ?? '',
      incidentDate: DateTime.parse(item['incident_date']),
      incidentLocation: item['incident_location'] ?? '',
      evidenceUrl: item['evidence_url'],
      evidenceVerificationState:
          item['evidence_verification_state'] ?? 'Unverified',
      evidenceVerificationDetails: item['evidence_verification_details'],
      aiSummary: item['ai_summary'],
      status: item['status'] ?? 'Pending',
      createdAt: DateTime.parse(item['created_at']),
      bullyName: item['bully_name'],
      bullyGradeSection: item['bully_grade_section'],
      witnesses: _parseWitnesses(item['witnesses']),
      reportSource: 'Parent-Reported',
      reporterId: _currentUser?.id,
      reporterName: _currentUser?.name,
      urgencyLevel: 'Moderate',
    );

    // Add timeline event
    await _supabase.from('timeline_events').insert({
      'report_id': item['id'],
      'title': 'Report Submitted',
      'description':
          'Incident report filed by ${_currentUser?.name ?? "parent"}.',
      'actor_name': _currentUser?.name ?? 'Parent',
      'actor_role': _currentUser?.roleString ?? 'Parent',
    });

    _reports.insert(0, newReport);
    notifyListeners();
    syncData();
    return newReport;
  }

  Future<ReportModel> submitAnonymousReport({
    required String title,
    required String description,
    required String category,
    required DateTime incidentDate,
    required String incidentLocation,
    String? victimName,
    String? victimGrade,
    String? victimSection,
    String? bullyName,
    String? bullyGradeSection,
    List<String>? witnesses,
    required String urgencyLevel,
    String? evidenceUrl,
  }) async {
    final studentDisplayName =
        (victimName != null && victimName.trim().isNotEmpty)
        ? victimName.trim()
        : 'Unidentified Student';
    final studentGradeName =
        (victimGrade != null && victimGrade.trim().isNotEmpty)
        ? victimGrade.trim()
        : 'Grade 7';
    final studentSectionName =
        (victimSection != null && victimSection.trim().isNotEmpty)
        ? victimSection.trim()
        : '$studentGradeName - Section To Be Determined';
    final reportTitle = title.trim().isNotEmpty
        ? title.trim()
        : 'Anonymous Bullying Report ($category)';
    final reportData = {
      'student_name': studentDisplayName,
      'student_grade': studentGradeName,
      'student_section': studentSectionName,
      'title': reportTitle,
      'description': description.trim(),
      'category': category,
      'incident_date': incidentDate.toIso8601String(),
      'incident_location': incidentLocation,
      'evidence_url': evidenceUrl,
      'bully_name': bullyName?.trim(),
      'bully_grade_section': bullyGradeSection?.trim(),
      'witnesses': witnesses,
      'urgency_level': urgencyLevel,
    };
    final reportId = await _supabase.rpc(
      'submit_anonymous_report',
      params: {'p_report': reportData},
    );

    final newReport = ReportModel(
      id: reportId.toString(),
      parentId: '',
      parentName: 'Anonymous Reporter',
      studentName: studentDisplayName,
      studentSection: studentSectionName,
      studentGrade: studentGradeName,
      title: reportTitle,
      description: description.trim(),
      category: category,
      incidentDate: incidentDate,
      incidentLocation: incidentLocation,
      evidenceUrl: evidenceUrl,
      evidenceVerificationState: 'Unverified',
      status: 'Pending',
      createdAt: DateTime.now(),
      bullyName: bullyName?.trim(),
      bullyGradeSection: bullyGradeSection?.trim(),
      witnesses: witnesses,
      reportSource: 'Anonymous',
      reporterId: null,
      reporterName: 'Anonymous Reporter',
      urgencyLevel: urgencyLevel,
    );
    _reports.insert(0, newReport);
    notifyListeners();
    syncData();
    return newReport;
  }

  Future<ReportModel> submitAdviserReport({
    required String title,
    required String description,
    required String category,
    required DateTime incidentDate,
    required String incidentLocation,
    required String studentName,
    required String studentSection,
    required String studentGrade,
    String? studentId,
    String? evidenceUrl,
    required String evidenceVerificationState,
    String? evidenceVerificationDetails,
    String? aiSummary,
    String? bullyName,
    String? bullyGradeSection,
    List<String>? witnesses,
    required String urgencyLevel,
  }) async {
    // BACKEND AUTHORIZATION: Advisers can only submit reports for their assigned section
    if (_currentUser?.role == UserRole.adviser) {
      final assigned = _currentUser?.assignedSection ?? '';
      if (assigned.isNotEmpty && !isSectionMatch(studentSection, assigned)) {
        throw Exception(
          'Security Authorization Error: Advisers are restricted to filing reports strictly within their assigned section ($assigned). Attempted: $studentSection',
        );
      }
    }

    final repData = {
      'parent_id': null,
      'parent_name': 'Adviser: ${_currentUser?.name ?? "Section Adviser"}',
      'student_id': studentId != null ? int.tryParse(studentId) : null,
      'student_name': studentName,
      'student_grade': studentGrade,
      'student_section': studentSection,
      'title': title,
      'description': description,
      'category': category,
      'incident_date': incidentDate.toIso8601String(),
      'incident_location': incidentLocation,
      'evidence_url': evidenceUrl,
      'evidence_verification_state': evidenceVerificationState,
      'evidence_verification_details': evidenceVerificationDetails,
      'ai_summary': aiSummary,
      'status': 'Pending',
      'bully_name': bullyName,
      'bully_grade_section': bullyGradeSection,
      'witnesses': witnesses != null ? json.encode(witnesses) : null,
    };

    final item = await _supabase
        .from('reports')
        .insert(repData)
        .select()
        .single();

    final newReport = ReportModel(
      id: item['id'].toString(),
      parentId: '',
      parentName: 'Adviser: ${_currentUser?.name ?? "Section Adviser"}',
      studentName: studentName,
      studentSection: studentSection,
      studentGrade: studentGrade,
      title: title,
      description: description,
      category: category,
      incidentDate: incidentDate,
      incidentLocation: incidentLocation,
      evidenceUrl: evidenceUrl,
      evidenceVerificationState: evidenceVerificationState,
      evidenceVerificationDetails: evidenceVerificationDetails,
      aiSummary: aiSummary,
      status: 'Pending',
      createdAt: DateTime.parse(item['created_at']),
      bullyName: bullyName,
      bullyGradeSection: bullyGradeSection,
      witnesses: witnesses,
      reportSource: 'Adviser-Observed',
      reporterId: _currentUser?.id,
      reporterName: _currentUser?.name,
      urgencyLevel: urgencyLevel,
    );

    await _supabase.from('timeline_events').insert({
      'report_id': item['id'],
      'title': 'Adviser Report Submitted',
      'description':
          'Incident report filed by adviser ${_currentUser?.name ?? ""}.',
      'actor_name': _currentUser?.name ?? 'Adviser',
      'actor_role': 'Adviser',
    });

    _reports.insert(0, newReport);
    notifyListeners();
    syncData();
    return newReport;
  }

  List<UserModel> getParentsList() {
    if (_currentUser?.role == UserRole.adviser &&
        _currentUser?.assignedSection != null &&
        _currentUser!.assignedSection!.isNotEmpty) {
      return _users.values
          .where(
            (p) => isSectionMatch(
              p.studentSection ?? '',
              _currentUser!.assignedSection!,
            ),
          )
          .toList();
    }
    return _users.values.toList();
  }

  // --- MEETINGS ---

  List<MeetingModel> getMeetingsForReport(String reportId) {
    _asyncFetchMeetings(reportId);
    return _meetings.where((m) => m.reportId == reportId).toList();
  }

  Future<void> _asyncFetchMeetings(String reportId) async {
    try {
      final repId = int.tryParse(reportId);
      if (repId == null) return;

      final data = await _supabase
          .from('meetings')
          .select()
          .eq('report_id', repId)
          .order('meeting_date');

      bool changed = false;
      for (var item in data) {
        final id = item['id'].toString();
        final idx = _meetings.indexWhere((m) => m.id == id);
        final m = MeetingModel(
          id: id,
          reportId: item['report_id'].toString(),
          scheduledByUserId: item['scheduled_by_user_id']?.toString() ?? '',
          scheduledByUserName: item['scheduled_by_user_name'] ?? 'Staff',
          scheduledByUserRole: item['scheduled_by_user_role'] ?? 'Adviser',
          meetingDate: DateTime.parse(item['meeting_date']),
          notes: item['notes'] ?? '',
          meetingType: item['meeting_type'] ?? 'In-Person',
          createdAt: DateTime.parse(item['created_at']),
        );
        if (idx != -1) {
          _meetings[idx] = m;
        } else {
          _meetings.add(m);
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  Future<MeetingModel> scheduleMeeting({
    required String reportId,
    required DateTime meetingDate,
    required String notes,
    required String meetingType,
  }) async {
    final repId = int.parse(reportId);

    final res = await _supabase
        .from('meetings')
        .insert({
          'report_id': repId,
          'scheduled_by_user_id': int.tryParse(_currentUser?.id ?? '0'),
          'scheduled_by_user_name': _currentUser?.name ?? 'Staff',
          'scheduled_by_user_role': _currentUser?.roleString ?? 'Adviser',
          'meeting_date': meetingDate.toIso8601String(),
          'notes': notes,
          'meeting_type': meetingType,
        })
        .select()
        .single();

    // Update report status
    await _supabase
        .from('reports')
        .update({'status': 'scheduled_meeting'})
        .eq('id', repId);

    // Insert timeline
    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Coordination Meeting Scheduled',
      'description':
          'Meeting scheduled by ${_currentUser?.name ?? "Adviser"} for ${meetingDate.toLocal()}.',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Adviser',
    });

    await syncData();
    await _asyncFetchMeetings(reportId);
    return _meetings.firstWhere((m) => m.id == res['id'].toString());
  }

  Future<MeetingModel> rescheduleMeeting({
    required String meetingId,
    required DateTime newDate,
    required String newNotes,
    required String newType,
  }) async {
    final mId = int.parse(meetingId);
    await _supabase
        .from('meetings')
        .update({
          'meeting_date': newDate.toIso8601String(),
          'notes': newNotes,
          'meeting_type': newType,
        })
        .eq('id', mId);

    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx != -1) {
      _meetings[idx] = _meetings[idx].copyWith(
        meetingDate: newDate,
        notes: newNotes,
        meetingType: newType,
      );
    }
    await syncData();
    notifyListeners();
    return _meetings[idx];
  }

  // --- CHATS ---

  List<ChatMessage> getMessagesForMeeting(String meetingId) {
    _asyncFetchChat(meetingId);
    return _messages.where((m) => m.meetingId == meetingId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _asyncFetchChat(String meetingId) async {
    try {
      final mId = int.tryParse(meetingId);
      if (mId == null) return;

      final data = await _supabase
          .from('chat_messages')
          .select()
          .eq('meeting_id', mId)
          .order('created_at');

      bool changed = false;
      for (var item in data) {
        final id = item['id'].toString();
        if (!_messages.any((m) => m.id == id)) {
          _messages.add(
            ChatMessage(
              id: id,
              meetingId: item['meeting_id'].toString(),
              senderId: item['sender_id'].toString(),
              senderName: item['sender_name'] ?? 'User',
              senderRole: item['sender_role'] ?? 'user',
              message: item['message'] ?? '',
              timestamp: DateTime.parse(item['created_at']),
              isReadByReceiver: item['is_read'] == true || item['is_read'] == 1,
            ),
          );
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  int getUnreadMessageCount(String meetingId) {
    if (_currentUser == null) return 0;
    return _messages
        .where(
          (m) =>
              m.meetingId == meetingId &&
              m.senderId != _currentUser!.id &&
              !m.isReadByReceiver,
        )
        .length;
  }

  void markMessagesAsRead(String meetingId) async {
    if (_currentUser == null) return;
    final mId = int.tryParse(meetingId);
    if (mId == null) return;

    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].meetingId == meetingId &&
          _messages[i].senderId != _currentUser!.id &&
          !_messages[i].isReadByReceiver) {
        _messages[i] = _messages[i].copyWith(isReadByReceiver: true);
      }
    }
    notifyListeners();

    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('meeting_id', mId)
          .neq('sender_id', int.tryParse(_currentUser!.id) ?? 0);
    } catch (_) {}
  }

  Future<ChatMessage> sendChatMessage({
    required String meetingId,
    required String messageText,
  }) async {
    final mId = int.parse(meetingId);

    final res = await _supabase
        .from('chat_messages')
        .insert({
          'meeting_id': mId,
          'sender_id': int.tryParse(_currentUser?.id ?? '0'),
          'sender_name': _currentUser?.name ?? 'User',
          'sender_role':
              _currentUser?.role.toString().split('.').last ?? 'parent',
          'message': messageText,
          'is_read': false,
        })
        .select()
        .single();

    final newMsg = ChatMessage(
      id: res['id'].toString(),
      meetingId: res['meeting_id'].toString(),
      senderId: res['sender_id'].toString(),
      senderName: res['sender_name'] ?? 'User',
      senderRole: res['sender_role'] ?? 'user',
      message: res['message'] ?? '',
      timestamp: DateTime.parse(res['created_at']),
      isReadByReceiver: false,
    );

    _messages.add(newMsg);
    notifyListeners();
    return newMsg;
  }

  // --- 5-STAGE WORKFLOW ACTIONS ---

  // STAGE 1 -> STAGE 2: OSD Initial Assessment -> Forward to Ministrong Tagasubaybay & Section Adviser
  Future<void> forwardForInitialIntervention({
    required String reportId,
    String? notes,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Forwarded for Initial Intervention';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        escalationNotes: notes,
        escalatedTo: 'Ministrong Tagasubaybay & Section Adviser',
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Stage 1 Completed: Forwarded for Initial Intervention',
        description:
            'OSD completed initial assessment and forwarded case to assigned Ministrong Tagasubaybay and Section Adviser for joint intervention.${notes != null && notes.isNotEmpty ? " Assessment notes: $notes" : ""}',
        actorName: _currentUser?.name ?? 'OSD Officer',
        actorRole: 'OSD',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'escalation_notes': notes,
            'escalated_to': 'Ministrong Tagasubaybay & Section Adviser',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', repId);
    }

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Stage 1 Completed: Forwarded for Initial Intervention',
      'description':
          'OSD completed initial assessment and forwarded case to assigned Ministrong Tagasubaybay and Section Adviser for joint intervention.${notes != null && notes.isNotEmpty ? " Assessment notes: $notes" : ""}',
      'actor_name': _currentUser?.name ?? 'OSD Officer',
      'actor_role': 'OSD',
    });

    try {
      await _supabase.from('notifications').insert({
        'recipient_role': 'ministrong_tagasubaybay',
        'title': 'Case #$repId Forwarded for Initial Intervention',
        'message':
            'OSD forwarded Case #$repId for joint initial intervention with Section Adviser.',
        'report_id': repId,
      });
    } catch (_) {}

    await syncData();
  }

  // STAGE 2 -> RESOLVED: Ministrong Tagasubaybay & Section Adviser resolve case
  Future<void> resolveCaseInitialIntervention({
    required String reportId,
    required String restorativeAction,
    required String notes,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Resolved';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        disciplineAction: restorativeAction,
        disciplineNotes: notes,
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title:
            'Stage 2 Completed: Case Resolved by Ministrong Tagasubaybay & Adviser',
        description:
            'Joint intervention successfully resolved the situation. Restorative Action: $restorativeAction. Agreement / Notes: $notes',
        actorName: _currentUser?.name ?? 'Staff',
        actorRole: _currentUser?.roleString ?? 'Staff',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'discipline_action': restorativeAction,
            'discipline_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {}

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title':
          'Stage 2 Completed: Case Resolved by Ministrong Tagasubaybay & Adviser',
      'description':
          'Joint intervention successfully resolved the situation. Restorative Action: $restorativeAction. Agreement / Notes: $notes',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });

    await syncData();
  }

  // STAGE 2 -> STAGE 3: Ministrong Tagasubaybay & Adviser escalate to OSD & Principal
  Future<void> escalateToOsdAndPrincipal({
    required String reportId,
    required String reason,
    String? notes,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Escalated to OSD and Principal';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        escalationReason: reason,
        escalationNotes: notes,
        escalatedTo: 'OSD and Principal',
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Stage 2 Escalation: Escalated to OSD and Principal',
        description:
            'Initial intervention could not manage or resolve the situation. Case escalated to OSD and Principal for joint higher intervention. Reason: $reason.${notes != null && notes.isNotEmpty ? " Notes: $notes" : ""}',
        actorName: _currentUser?.name ?? 'Staff',
        actorRole: _currentUser?.roleString ?? 'Staff',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'escalation_reason': reason,
            'escalation_notes': notes,
            'escalated_to': 'OSD and Principal',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', repId);
    }

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Stage 2 Escalation: Escalated to OSD and Principal',
      'description':
          'Initial intervention could not manage or resolve the situation. Case escalated to OSD and Principal for joint higher intervention. Reason: $reason.${notes != null && notes.isNotEmpty ? " Notes: $notes" : ""}',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });

    try {
      await _supabase.from('notifications').insert({
        'recipient_role': 'principal',
        'title': 'Case #$repId Escalated to OSD & Principal',
        'message': 'Case escalated by ${_currentUser?.name}. Reason: $reason',
        'report_id': repId,
      });
    } catch (_) {}

    await syncData();
  }

  // STAGE 3 -> RESOLVED: OSD & Principal resolve case
  Future<void> resolveCaseOsdAndPrincipal({
    required String reportId,
    required String disciplineAction,
    required String notes,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Resolved';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        disciplineAction: disciplineAction,
        disciplineNotes: notes,
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Stage 3 Completed: Case Resolved by OSD and Principal',
        description:
            'OSD and Principal joint intervention finalized decision. Disciplinary Action / Sanction: $disciplineAction. Official Findings & Notes: $notes',
        actorName: _currentUser?.name ?? 'Staff',
        actorRole: _currentUser?.roleString ?? 'Staff',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'discipline_action': disciplineAction,
            'discipline_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {}

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Stage 3 Completed: Case Resolved by OSD and Principal',
      'description':
          'OSD and Principal joint intervention finalized decision. Disciplinary Action / Sanction: $disciplineAction. Official Findings & Notes: $notes',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });

    await syncData();
  }

  // STAGE 3 -> STAGE 4: OSD & Principal escalate to Board of Discipline
  Future<void> escalateToBoardOfDiscipline({
    required String reportId,
    required String reason,
    String? notes,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Escalated to Board of Discipline';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        escalationReason: reason,
        escalationNotes: notes,
        escalatedTo: 'Board of Discipline',
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Stage 3 Escalation: Escalated to Board of Discipline',
        description:
            'OSD and Principal determined case warrants formal Board proceedings. Reason: $reason.${notes != null && notes.isNotEmpty ? " Notes: $notes" : ""}',
        actorName: _currentUser?.name ?? 'Staff',
        actorRole: _currentUser?.roleString ?? 'Staff',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'escalation_reason': reason,
            'escalation_notes': notes,
            'escalated_to': 'Board of Discipline',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', repId);
    }

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Stage 3 Escalation: Escalated to Board of Discipline',
      'description':
          'OSD and Principal determined case warrants formal Board proceedings. Reason: $reason.${notes != null && notes.isNotEmpty ? " Notes: $notes" : ""}',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });

    try {
      await _supabase.from('notifications').insert({
        'recipient_role': 'board_of_discipline',
        'title': 'Case #$repId Escalated to Board of Discipline',
        'message':
            'Case escalated to Board of Discipline by ${_currentUser?.name}. Reason: $reason',
        'report_id': repId,
      });
    } catch (_) {}

    await syncData();
  }

  // STAGE 4 -> STAGE 5: Board of Discipline Final Deliberation & Punishment -> Forward to School President
  Future<void> finalizeBoardDecisionAndForwardToPresident({
    required String reportId,
    required String findings,
    required String decision,
    required String punishment,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Forwarded to School President';

    final combinedNotes =
        'Board Findings: $findings\nDecision: $decision\nPunishment: $punishment';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        disciplineAction: punishment,
        disciplineNotes: combinedNotes,
        boardFindings: findings,
        boardDecision: decision,
        punishmentImposed: punishment,
        escalatedTo: 'School President',
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title:
            'Stage 4 Completed: Board Deliberation Finalized & Punishment Imposed',
        description:
            'Board of Discipline finalized disciplinary decision and imposed punishment ($punishment). Case forwarded to School President for final executive review.\nFindings: $findings\nDecision: $decision',
        actorName: _currentUser?.name ?? 'Board Chairman',
        actorRole: 'Board of Discipline',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'discipline_action': punishment,
            'discipline_notes': combinedNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', repId);
    }

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title':
          'Stage 4 Completed: Board Deliberation Finalized & Punishment Imposed',
      'description':
          'Board of Discipline finalized disciplinary decision and imposed punishment ($punishment). Case forwarded to School President for final executive review.\nFindings: $findings\nDecision: $decision',
      'actor_name': _currentUser?.name ?? 'Board Chairman',
      'actor_role': 'Board of Discipline',
    });

    try {
      await _supabase.from('notifications').insert({
        'recipient_role': 'school_president',
        'title': 'Case #$repId Forwarded for Final Review',
        'message':
            'Board of Discipline determined punishment for Case #$repId. Awaiting School President final review.',
        'report_id': repId,
      });
    } catch (_) {}

    await syncData();
  }

  // STAGE 5: School President Final Review & Finalization
  Future<void> completePresidentReview({
    required String reportId,
    required String remarks,
  }) async {
    final repId = int.parse(reportId);
    const newStatus = 'Finalized by School President';

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        presidentNotes: remarks,
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Stage 5 Completed: Final Review Completed by School President',
        description:
            'School President conducted final executive review of completed disciplinary proceedings and affirmed case disposition. Executive Remarks: $remarks',
        actorName: _currentUser?.name ?? 'School President',
        actorRole: 'School President',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {}

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Stage 5 Completed: Final Review Completed by School President',
      'description':
          'School President conducted final executive review of completed disciplinary proceedings and affirmed case disposition. Executive Remarks: $remarks',
      'actor_name': _currentUser?.name ?? 'School President',
      'actor_role': 'School President',
    });

    await syncData();
  }

  // --- COMPATIBILITY WRAPPERS ---

  Future<void> escalateReport({
    required String reportId,
    required String reason,
    String? notes,
  }) async {
    final repId = int.parse(reportId);
    String targetAuthority = 'Principal';
    String newStatus = 'Escalated to Principal';

    if (_currentUser?.role == UserRole.principal) {
      targetAuthority = 'Ministrong Tagasubaybay';
      newStatus = 'Escalated to Ministrong Tagasubaybay';
    } else if (_currentUser?.role == UserRole.ministrong_tagasubaybay) {
      targetAuthority = 'OSD';
      newStatus = 'Escalated to OSD';
    }

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: newStatus,
        escalationReason: reason,
        escalationNotes: notes,
        escalatedTo: targetAuthority,
      );
      notifyListeners();
    }

    _timelines.insert(
      0,
      TimelineEvent(
        id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: 'Case Escalated to $targetAuthority',
        description: notes != null && notes.isNotEmpty
            ? 'Reason: $reason. Notes: $notes'
            : 'Reason: $reason',
        actorName: _currentUser?.name ?? 'Staff',
        actorRole: _currentUser?.roleString ?? 'Staff',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'escalation_reason': reason,
            'escalation_notes': notes,
            'escalated_to': targetAuthority,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', repId);
    } catch (_) {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', repId);
    }

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Case Escalated to $targetAuthority',
      'description': notes != null && notes.isNotEmpty
          ? 'Reason: $reason. Notes: $notes'
          : 'Reason: $reason',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });

    try {
      await _supabase.from('notifications').insert({
        'recipient_role': targetAuthority.toLowerCase().contains('ministro')
            ? 'ministrong_tagasubaybay'
            : (targetAuthority.toLowerCase().contains('osd')
                  ? 'osd'
                  : 'principal'),
        'title': 'Case Escalation: Case #$repId',
        'message':
            'Case escalated to $targetAuthority by ${_currentUser?.name}. Reason: $reason',
        'report_id': repId,
      });
    } catch (_) {}

    await syncData();
  }

  Future<void> resolveReport({
    required String reportId,
    required String disciplineAction,
    required String disciplineNotes,
  }) async {
    final repId = int.parse(reportId);

    await _supabase
        .from('reports')
        .update({
          'status': 'Resolved',
          'discipline_action': disciplineAction,
          'discipline_notes': disciplineNotes,
        })
        .eq('id', repId);

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Case Resolved',
      'description':
          'Case resolved by ${_currentUser?.name ?? "Staff"}. Disciplinary Action: $disciplineAction. Notes: $disciplineNotes',
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });
    await syncData();
  }

  Future<void> appealReport({
    required String reportId,
    required String reason,
  }) async {
    final repId = int.parse(reportId);
    final rep = _reports.firstWhere((r) => r.id == reportId);
    final count = rep.appealCount + 1;

    await _supabase
        .from('reports')
        .update({
          'status': 'appealed',
          'appealed_reason': reason,
          'appeal_count': count,
        })
        .eq('id', repId);

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Case Appealed',
      'description': 'Parent submitted appeal. Reason: $reason',
      'actor_name': _currentUser?.name ?? 'Parent',
      'actor_role': 'Parent',
    });
    await syncData();
  }

  Future<void> reAppealReport({
    required String reportId,
    required String reason,
    String? comments,
    String? newEvidenceUrl,
  }) async {
    final repId = int.parse(reportId);
    final rep = _reports.firstWhere((r) => r.id == reportId);
    final count = rep.appealCount + 1;

    await _supabase
        .from('reports')
        .update({
          'status': 'appealed',
          'appealed_reason': reason,
          'appeal_count': count,
        })
        .eq('id', repId);

    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Case Re-appealed',
      'description':
          'Parent submitted a re-appeal (Appeal #$count). Reason: $reason',
      'actor_name': _currentUser?.name ?? 'Parent',
      'actor_role': 'Parent',
    });
    await syncData();
  }

  // --- TIMELINE ---

  List<TimelineEvent> getTimelineEvents(String reportId) {
    _asyncFetchTimeline(reportId);
    return _timelines.where((t) => t.reportId == reportId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _asyncFetchTimeline(String reportId) async {
    try {
      final repId = int.tryParse(reportId);
      if (repId == null) return;

      final data = await _supabase
          .from('timeline_events')
          .select()
          .eq('report_id', repId)
          .order('created_at', ascending: false);

      bool changed = false;
      for (var item in data) {
        final id = item['id'].toString();
        if (!_timelines.any((t) => t.id == id)) {
          _timelines.add(
            TimelineEvent(
              id: id,
              reportId: item['report_id'].toString(),
              title: item['title'] ?? '',
              description: item['description'] ?? '',
              actorName: item['actor_name'] ?? '',
              actorRole: item['actor_role'] ?? 'System',
              timestamp: DateTime.parse(item['created_at']),
            ),
          );
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  Future<void> updateAiSummary(String reportId, String summary) async {
    final repId = int.parse(reportId);
    await _supabase
        .from('reports')
        .update({'ai_summary': summary})
        .eq('id', repId);

    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(aiSummary: summary);
    }
    notifyListeners();
  }

  Future<void> addTimelineNote(String reportId, String description) async {
    final repId = int.parse(reportId);
    await _supabase.from('timeline_events').insert({
      'report_id': repId,
      'title': 'Official Note Added',
      'description': description,
      'actor_name': _currentUser?.name ?? 'Staff',
      'actor_role': _currentUser?.roleString ?? 'Staff',
    });
    await syncData();
    await _asyncFetchTimeline(reportId);
  }

  // --- MULTIPLE CHILDREN MANAGEMENT ---

  Future<UserModel> addChild({
    required String certificateFilename,
    required String studentName,
    required String sectionName,
    required String gradeLevel,
    required String academicYear,
  }) async {
    if (_currentUser == null) throw Exception('Not authenticated.');

    await _supabase.from('students').insert({
      'parent_id': int.parse(_currentUser!.id),
      'name': studentName,
      'grade': gradeLevel,
      'section': sectionName,
      'academic_year': academicYear,
    });

    final uJson = await _supabase
        .from('users')
        .select(
          'id, auth_user_id, email, name, role, avatar_url, assigned_section, student_name, student_grade, student_section, academic_year, created_at, updated_at, students(*)',
        )
        .eq('id', int.parse(_currentUser!.id))
        .single();

    _currentUser = UserModel.fromJson(uJson);

    if (_selectedChild == null &&
        _currentUser!.students != null &&
        _currentUser!.students!.isNotEmpty) {
      _selectedChild = _currentUser!.students!.first;
    }
    notifyListeners();
    return _currentUser!;
  }

  // --- AI SUMMARIES ENDPOINTS ---

  Future<Map<String, dynamic>> getAiSummary(
    String period, {
    String? studentId,
    String? className,
  }) async {
    try {
      var query = _supabase.from('ai_summaries').select().eq('period', period);
      if (studentId != null) query = query.eq('scope_id', studentId);
      final results = await query.order('id', ascending: false).limit(1);

      if (results.isNotEmpty) {
        final item = results.first;
        return {
          'summary': item['summary_text'] ?? '',
          'stats': item['stats'] ?? {},
        };
      }
    } catch (_) {}

    return {
      'summary':
          'No incident alerts for this period. Campus safety standards are currently maintained.',
      'stats': {
        'total_cases': 0,
        'resolved_cases': 0,
        'pending_cases': 0,
        'escalated_cases': 0,
      },
    };
  }

  Future<Map<String, dynamic>> refreshAiSummary(
    String period, {
    String? studentId,
    String? className,
  }) async {
    return getAiSummary(period, studentId: studentId, className: className);
  }

  // --- DUPLICATE FLAGS MANAGEMENT ENDPOINTS ---

  Future<List<dynamic>> getDuplicateFlags() async {
    try {
      final flags = await _supabase
          .from('duplicate_flags')
          .select()
          .order('id', ascending: false);
      return flags;
    } catch (e) {
      return [];
    }
  }

  Future<void> resolveDuplicateFlag(String id, String status) async {
    await _supabase
        .from('duplicate_flags')
        .update({'status': status})
        .eq('id', int.parse(id));
  }

  Future<void> deleteDuplicateAccount(String id) async {
    await _supabase.from('duplicate_flags').delete().eq('id', int.parse(id));
  }

  // --- GAP 4: AUDIT LOGGING & LOGIN HISTORY ---

  Future<void> logLoginAttempt({
    String? userId,
    required String email,
    required bool success,
    String? failureReason,
  }) async {
    try {
      await _supabase.from('login_history').insert({
        'user_id': userId != null ? int.tryParse(userId) : null,
        'attempted_email': email,
        'status': success ? 'SUCCESS' : 'FAILURE',
        'failure_reason': failureReason,
        'ip_address': '127.0.0.1 (Mobile App)',
        'device_info': 'HayagSync Flutter Client',
      });
    } catch (_) {}
  }

  Future<void> logActivity({
    required String action,
    required String entityName,
    required String recordId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      await _supabase.from('activity_logs').insert({
        'user_id': int.tryParse(_currentUser?.id ?? '0'),
        'user_email': _currentUser?.email,
        'user_role': _currentUser?.roleString,
        'action': action,
        'entity_name': entityName,
        'record_id': recordId,
        'old_values': oldValues,
        'new_values': newValues,
        'ip_address': '127.0.0.1 (Mobile App)',
      });
    } catch (_) {}
  }
}
