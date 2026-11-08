import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';
import 'staff_report_detail.dart';
import 'ai_summary_screen.dart';
import 'duplicate_manager_screen.dart';
import 'adviser_submit_report.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseService();

  String? _selectedStatusFilter;
  String? _selectedSectionFilter;
  String? _selectedGradeFilter;
  bool _filterAnonymousOnly = false;
  final _reportSearchController = TextEditingController();
  final _parentSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _db.addListener(_onDbUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _db.removeListener(_onDbUpdate);
    _reportSearchController.dispose();
    _parentSearchController.dispose();
    super.dispose();
  }

  void _onDbUpdate() {
    if (mounted) setState(() {});
  }

  void _handleLogout() {
    _db.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _toggleStageFilter(String stage) {
    setState(() {
      if (_selectedStatusFilter == stage) {
        _selectedStatusFilter = null;
      } else {
        _selectedStatusFilter = stage;
      }
    });
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_selectedStatusFilter == status) {
        _selectedStatusFilter = null; // Clear filter on double click
      } else {
        _selectedStatusFilter = status;
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final staff = _db.currentUser;
    if (staff == null) return const SizedBox();

    // Query reports based on RLS rules
    var reports = _db.getReports();

    // Calculate counts for 5-stage workflow stats cards
    final stage1Count = reports.where((r) => r.stageNumber == 1 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').length;
    final stage2Count = reports.where((r) => r.stageNumber == 2 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').length;
    final stage3Count = reports.where((r) => r.stageNumber == 3 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').length;
    final stage4Count = reports.where((r) => r.stageNumber == 4 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').length;
    final stage5Count = reports.where((r) => r.stageNumber == 5 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').length;
    final resolvedCount = reports.where((r) => r.status.toLowerCase() == 'resolved' || r.status.toLowerCase() == 'closed').length;
    final anonymousCount = reports.where((r) => r.isAnonymous).length;
    final escalatedCount = reports.where((r) => r.status.toLowerCase().contains('escalat') || r.stageNumber >= 2).length;

    // Apply Stage / Status Filter
    if (_selectedStatusFilter != null) {
      if (_selectedStatusFilter == 'stage_1') {
        reports = reports.where((r) => r.stageNumber == 1 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').toList();
      } else if (_selectedStatusFilter == 'stage_2') {
        reports = reports.where((r) => r.stageNumber == 2 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').toList();
      } else if (_selectedStatusFilter == 'stage_3') {
        reports = reports.where((r) => r.stageNumber == 3 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').toList();
      } else if (_selectedStatusFilter == 'stage_4') {
        reports = reports.where((r) => r.stageNumber == 4 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').toList();
      } else if (_selectedStatusFilter == 'stage_5') {
        reports = reports.where((r) => r.stageNumber == 5 && r.status.toLowerCase() != 'resolved' && r.status.toLowerCase() != 'closed').toList();
      } else if (_selectedStatusFilter == 'resolved') {
        reports = reports.where((r) => r.status.toLowerCase() == 'resolved' || r.status.toLowerCase() == 'closed').toList();
      } else {
        reports = reports.where((r) => r.status.toLowerCase() == _selectedStatusFilter).toList();
      }
    }

    // Apply Grade Filter
    if (_selectedGradeFilter != null) {
      reports = reports.where((r) => r.studentGrade == _selectedGradeFilter || r.studentSection.contains(_selectedGradeFilter!)).toList();
    }

    // Apply Anonymous Filter
    if (_filterAnonymousOnly) {
      reports = reports.where((r) => r.isAnonymous).toList();
    }

    // Apply Section Filter
    if (_selectedSectionFilter != null) {
      reports = reports.where((r) => r.studentSection == _selectedSectionFilter).toList();
    }

    // Apply Search Filter for reports
    final repQuery = _reportSearchController.text.trim().toLowerCase();
    if (repQuery.isNotEmpty) {
      reports = reports.where((r) =>
        r.studentName.toLowerCase().contains(repQuery) ||
        r.title.toLowerCase().contains(repQuery) ||
        r.category.toLowerCase().contains(repQuery) ||
        r.id.toLowerCase().contains(repQuery) ||
        r.studentSection.toLowerCase().contains(repQuery) ||
        (r.bullyName != null && r.bullyName!.toLowerCase().contains(repQuery))
      ).toList();
    }

    var parentsList = _db.getParentsList();
    final parQuery = _parentSearchController.text.trim().toLowerCase();
    if (parQuery.isNotEmpty) {
      parentsList = parentsList.where((p) =>
        p.name.toLowerCase().contains(parQuery) ||
        (p.studentName != null && p.studentName!.toLowerCase().contains(parQuery)) ||
        (p.email.toLowerCase().contains(parQuery)) ||
        (p.studentSection != null && p.studentSection!.toLowerCase().contains(parQuery))
      ).toList();
    }

    final allSections = [
      'Grade 7 - Mahogany',
      'Grade 7 - Narra',
      'Grade 8 - Uranus',
      'Grade 8 - Venus',
      'Grade 9 - Eagle',
      'Grade 9 - Falcon',
      'Grade 10 - Rizal',
      'Grade 10 - Bonifacio',
      'Grade 10 - Jupiter',
      'Grade 11 - STEM A',
      'Grade 11 - ABM A',
      'Grade 12 - STEM A',
      'Grade 12 - ABM A',
    ];

    // Determine role banner gradient colors
    List<Color> bannerColors;
    String roleBadge;
    if (staff.role == UserRole.adviser) {
      bannerColors = const [Color(0xFF0F766E), Color(0xFF0D9488)]; // Teal
      roleBadge = 'Section Adviser';
    } else if (staff.role == UserRole.principal) {
      bannerColors = const [Color(0xFF1E40AF), Color(0xFF2563EB)]; // Blue
      roleBadge = 'School Principal';
    } else if (staff.role == UserRole.ministrong_tagasubaybay) {
      bannerColors = const [Color(0xFF7C3AED), Color(0xFF8B5CF6)]; // Purple
      roleBadge = 'Ministrong Tagasubaybay';
    } else if (staff.role == UserRole.board_of_discipline) {
      bannerColors = const [Color(0xFF9333EA), Color(0xFFC026D3)]; // Fuchsia
      roleBadge = 'Board of Discipline';
    } else if (staff.role == UserRole.school_president) {
      bannerColors = const [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]; // Navy
      roleBadge = 'School President';
    } else {
      bannerColors = const [Color(0xFF1E293B), Color(0xFF475569)]; // Slate (OSD)
      roleBadge = 'Office of Student Discipline (OSD)';
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HAYAGSYNC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                ),
                Text(
                  'Staff Portal | $roleBadge',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'AI Summaries',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSummaryScreen()),
              );
            },
          ),
          if (staff.role == UserRole.principal || staff.role == UserRole.osd)
            IconButton(
              icon: const Icon(Icons.group_off_outlined),
              tooltip: 'Duplicate Accounts Manager',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DuplicateManagerScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Incident Management'),
            Tab(icon: Icon(Icons.people_outline), text: 'Parents Directory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // INCIDENT MANAGEMENT VIEW
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Body Header Banner (Role Gradient)
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: bannerColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: bannerColors.first.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              staff.name.substring(0, 2).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        roleBadge,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (staff.role == UserRole.adviser) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'Assigned: ${staff.assignedSection}',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_db.getStudents().length} Students',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (staff.role == UserRole.adviser) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AdviserSubmitReportScreen()),
                                );
                              },
                              icon: const Icon(Icons.add_alert_outlined, size: 18),
                              label: const Text('Create Incident Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F766E),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ],
                          if (staff.role == UserRole.osd || staff.role == UserRole.ministrong_tagasubaybay) ...[
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: escalatedCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                boxShadow: [
                                  if (escalatedCount > 0)
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$escalatedCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    escalatedCount == 1 ? 'ESCALATION' : 'ESCALATIONS',
                                    style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Statistics Row: 5-Stage Multi-Level Incident Progress + Resolved
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isMobile = constraints.maxWidth < 750;
                        if (isMobile) {
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.15,
                            children: [
                              _buildStatCard('Stage 1: OSD', stage1Count, const Color(0xFF2563EB), const Color(0xFFEFF6FF), 'stage_1'),
                              _buildStatCard('Stage 2: Ministro+Adv', stage2Count, const Color(0xFF0F766E), const Color(0xFFF0FDFA), 'stage_2'),
                              _buildStatCard('Stage 3: OSD+Prin', stage3Count, const Color(0xFFD97706), const Color(0xFFFFFBEB), 'stage_3'),
                              _buildStatCard('Stage 4: Board', stage4Count, const Color(0xFF86198F), const Color(0xFFFDF4FF), 'stage_4'),
                              _buildStatCard('Stage 5: President', stage5Count, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF), 'stage_5'),
                              _buildStatCard('Resolved', resolvedCount, const Color(0xFF16A34A), const Color(0xFFF0FDF4), 'resolved'),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: _buildStatCard('Stage 1: OSD', stage1Count, const Color(0xFF2563EB), const Color(0xFFEFF6FF), 'stage_1')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildStatCard('Stage 2: Ministro & Adviser', stage2Count, const Color(0xFF0F766E), const Color(0xFFF0FDFA), 'stage_2')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildStatCard('Stage 3: OSD & Principal', stage3Count, const Color(0xFFD97706), const Color(0xFFFFFBEB), 'stage_3')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildStatCard('Stage 4: Board Delib.', stage4Count, const Color(0xFF86198F), const Color(0xFFFDF4FF), 'stage_4')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildStatCard('Stage 5: President Review', stage5Count, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF), 'stage_5')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildStatCard('Resolved', resolvedCount, const Color(0xFF16A34A), const Color(0xFFF0FDF4), 'resolved')),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Filter toolbar with Grade, Section, Anonymous, and Active Chips
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Incident Reports Log',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedStatusFilter != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  _selectedStatusFilter!.toUpperCase().replaceAll('_', ' '),
                                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                onDeleted: () => setState(() => _selectedStatusFilter = null),
                                deleteIconColor: const Color(0xFF2563EB),
                              ),
                            ],
                            if (_selectedGradeFilter != null) ...[
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  _selectedGradeFilter!,
                                  style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: const Color(0xFFF5F3FF),
                                side: const BorderSide(color: Color(0xFFDDD6FE)),
                                onDeleted: () => setState(() => _selectedGradeFilter = null),
                                deleteIconColor: const Color(0xFF7C3AED),
                              ),
                            ],
                            if (_selectedSectionFilter != null) ...[
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  _selectedSectionFilter!,
                                  style: const TextStyle(color: Color(0xFF0D9488), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: const Color(0xFFF0FDFA),
                                side: const BorderSide(color: Color(0xFF99F6E4)),
                                onDeleted: () => setState(() => _selectedSectionFilter = null),
                                deleteIconColor: const Color(0xFF0D9488),
                              ),
                            ],
                          ],
                        ),

                        // Filters row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Anonymous Reports Filter Toggle
                            FilterChip(
                              avatar: Icon(Icons.visibility_off, size: 14, color: _filterAnonymousOnly ? Colors.white : const Color(0xFF475569)),
                              label: Text(
                                'Anonymous Only ($anonymousCount)',
                                style: TextStyle(
                                  color: _filterAnonymousOnly ? Colors.white : const Color(0xFF334155),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: _filterAnonymousOnly,
                              selectedColor: const Color(0xFF334155),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: _filterAnonymousOnly ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              onSelected: (val) => setState(() => _filterAnonymousOnly = val),
                            ),

                            // Grade Level Filter Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedGradeFilter,
                                hint: const Text('Filter Grade', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                underline: const SizedBox(),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                items: const [
                                  DropdownMenuItem<String>(value: null, child: Text('All Grades')),
                                  DropdownMenuItem<String>(value: 'Grade 7', child: Text('Grade 7')),
                                  DropdownMenuItem<String>(value: 'Grade 8', child: Text('Grade 8')),
                                  DropdownMenuItem<String>(value: 'Grade 9', child: Text('Grade 9')),
                                  DropdownMenuItem<String>(value: 'Grade 10', child: Text('Grade 10')),
                                  DropdownMenuItem<String>(value: 'Grade 11', child: Text('Grade 11')),
                                  DropdownMenuItem<String>(value: 'Grade 12', child: Text('Grade 12')),
                                ],
                                onChanged: (val) => setState(() => _selectedGradeFilter = val),
                              ),
                            ),

                            // Section Dropdown for Staff Roles
                            if (staff.role != UserRole.adviser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedSectionFilter,
                                  hint: const Text('Filter Section', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  underline: const SizedBox(),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                  items: [
                                    const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                                    ...allSections.map((sec) => DropdownMenuItem<String>(value: sec, child: Text(sec))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedSectionFilter = val),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Search Input for Reports
                    TextField(
                      controller: _reportSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: staff.role == UserRole.adviser
                            ? 'Search students or cases in ${staff.assignedSection}...'
                            : 'Search all students, cases, or sections...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: _reportSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _reportSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Reports Table / List
                    _buildReportsList(reports),
                  ],
                ),
              ),
            ),
          ),

          // PARENTS DIRECTORY VIEW
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          staff.role == UserRole.adviser
                              ? 'Section Registered Directory (${staff.assignedSection})'
                              : 'Global Registered Parent Directory (All Sections)',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${parentsList.length} Parents',
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Input for Parents
                    TextField(
                      controller: _parentSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: staff.role == UserRole.adviser
                            ? 'Search parents or students in ${staff.assignedSection}...'
                            : 'Search parents or students across all sections...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: _parentSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _parentSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildParentsTable(parentsList),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, Color bg, String filterValue) {
    final isSelected = _selectedStatusFilter == filterValue;
    return Card(
      color: isSelected ? bg : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleStatusFilter(filterValue),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(List<ReportModel> reports) {
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
            Icon(Icons.rule_folder_outlined, size: 44, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No incident reports found matching this criteria.',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
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
                  builder: (_) => StaffReportDetailScreen(reportId: report.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStageBadge(report),
                          StatusBadge(status: report.status),
                          if (report.isAnonymous)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.visibility_off, size: 11, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'ANONYMOUS',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Text(
                        report.createdAt.toLocal().toString().substring(0, 10),
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.title,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.description,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Victim: ${report.studentName} (${report.studentGrade})',
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (report.bullyName != null && report.bullyName!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Alleged Bully: ${report.bullyName}',
                                    style: const TextStyle(color: Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.class_outlined, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Section: ${report.studentSection}',
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_outlined, size: 13, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  'Handling: ${report.currentHandlingOffice}',
                                  style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParentsTable(List<UserModel> parents) {
    if (parents.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 44, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No parents registered in this directory yet.',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          constraints: const BoxConstraints(minWidth: 500),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            children: [
              // Table Header
              const TableRow(
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Parent Name', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Student Name', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Section', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              
              // Table Content
              ...parents.map((p) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(p.name, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(p.studentName ?? 'N/A', style: const TextStyle(color: Color(0xFF334155), fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(p.studentSection ?? 'N/A', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageBadge(ReportModel report) {
    Color bg;
    Color fg;
    String label;
    if (report.status.toLowerCase() == 'resolved' || report.status.toLowerCase() == 'closed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'RESOLVED';
    } else {
      switch (report.stageNumber) {
        case 1:
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFF92400E);
          label = 'STAGE 1: OSD ASSESSMENT';
          break;
        case 2:
          bg = const Color(0xFFEDE9FE);
          fg = const Color(0xFF5B21B6);
          label = 'STAGE 2: MINISTRO & ADVISER';
          break;
        case 3:
          bg = const Color(0xFFDBEAFE);
          fg = const Color(0xFF1E40AF);
          label = 'STAGE 3: OSD & PRINCIPAL';
          break;
        case 4:
          bg = const Color(0xFFFCE7F3);
          fg = const Color(0xFF9D174D);
          label = 'STAGE 4: BOARD OF DISCIPLINE';
          break;
        case 5:
          bg = const Color(0xFFE0E7FF);
          fg = const Color(0xFF3730A3);
          label = 'STAGE 5: PRESIDENT REVIEW';
          break;
        default:
          bg = const Color(0xFFF1F5F9);
          fg = const Color(0xFF475569);
          label = 'STAGE ${report.stageNumber}';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
