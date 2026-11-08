import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';

class AiSummaryScreen extends StatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  final _db = DatabaseService();
  final _ai = AIService();
  String _selectedPeriod = 'weekly'; // weekly, monthly, yearly
  String _selectedPerspective = 'adviser'; // adviser, osd, principal, board

  // Scoped filters
  StudentModel? _parentSelectedChild;
  String? _selectedClass; // For Principal / OSD / Board

  bool _isLoading = false;
  String? _errorMessage;
  String? _summaryText;
  Map<String, dynamic>? _stats;
  String _lastGenerated = 'Never';

  final List<String> _classSections = [
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

  @override
  void initState() {
    super.initState();
    final user = _db.currentUser;
    if (user != null) {
      if (user.role == UserRole.parent) {
        _parentSelectedChild = _db.selectedChild;
        _selectedPerspective = 'adviser';
      } else if (user.role == UserRole.adviser) {
        _selectedClass = user.assignedSection;
        _selectedPerspective = 'adviser';
      } else if (user.role == UserRole.principal) {
        _selectedPerspective = 'principal';
      } else if (user.role == UserRole.osd ||
          user.role == UserRole.ministrong_tagasubaybay) {
        _selectedPerspective = 'osd';
      } else {
        _selectedPerspective = 'board';
      }
    }
    _loadSummary();
  }

  Future<void> _loadSummary({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _db.currentUser;
      if (user == null) throw Exception('No logged-in user.');

      // Layer 4 intelligence operates on resolved & archived records
      var resolvedReports = _db.reports.where((r) {
        final s = r.status.toLowerCase();
        return s == 'resolved' || s == 'archived';
      }).toList();

      if (user.role == UserRole.parent && _parentSelectedChild != null) {
        resolvedReports = resolvedReports
            .where((r) => r.studentName == _parentSelectedChild!.name)
            .toList();
      }

      final data = _ai.generatePostResolutionTrendReport(
        resolvedReports: resolvedReports,
        period: _selectedPeriod,
        roleKey: _selectedPerspective,
        sectionFilter: _selectedClass,
      );

      await _db.saveAiSummary(
        period: _selectedPeriod,
        summary: data['summary_text'] as String,
        stats: Map<String, dynamic>.from(data['stats'] as Map),
        scopeId: user.role == UserRole.parent
            ? _parentSelectedChild?.id
            : _selectedClass,
      );

      setState(() {
        _summaryText = data['summary_text'];
        _stats = data['stats'];
        final now = DateTime.now();
        _lastGenerated =
            '${now.month}/${now.day}/${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _db.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text('Unauthorized')));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Post-Resolution Trend & Prevention',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ethics / Non-Punitive System Banner
                _buildEthicsPolicyBanner(),
                const SizedBox(height: 14),

                // Perspective Selector
                _buildPerspectiveTabs(),
                const SizedBox(height: 12),

                // Period Filter Row
                _buildPeriodFilterRow(),
                const SizedBox(height: 12),

                // Role-scoped context filters
                _buildRoleContextFilters(),
                const SizedBox(height: 14),

                // Last generated & refresh button row
                _buildHeaderControlRow(),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Card(
                    color: Color(0xFF1E293B),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF2563EB)),
                          SizedBox(height: 16),
                          Text(
                            'Aggregating resolved records & generating prevention intelligence...',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  Card(
                    color: const Color(0xFF451A03),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF78350F)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFF59E0B),
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Stats Visualizer Card
                  if (_stats != null) ...[
                    _buildStatsVisualizerCard(),
                    const SizedBox(height: 16),
                  ],

                  // AI Analysis Markdown Card
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _summaryText != null
                          ? MarkdownText(text: _summaryText!)
                          : const Center(
                              child: Text(
                                'No summary content loaded.',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEthicsPolicyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'De-Identified Institutional Intelligence (Layer 4)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Operates strictly on resolved and archived records. Designed for environmental prevention, restorative homeroom guidance, and staff patrol allocation. Zero individual student profiling or automated punitive measures.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerspectiveTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPerspectivePill(
            'Adviser / Homeroom',
            'adviser',
            Icons.school_outlined,
          ),
          const SizedBox(width: 8),
          _buildPerspectivePill(
            'OSD / Patrol',
            'osd',
            Icons.local_police_outlined,
          ),
          const SizedBox(width: 8),
          _buildPerspectivePill(
            'Principal / Policy',
            'principal',
            Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(width: 8),
          _buildPerspectivePill(
            'Board / Governance',
            'board',
            Icons.account_balance_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPerspectivePill(String title, String key, IconData icon) {
    final isSelected = _selectedPerspective == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedPerspective = key);
        _loadSummary();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilterRow() {
    return Row(
      children: [
        _buildPeriodButton('Weekly Trends', 'weekly'),
        const SizedBox(width: 8),
        _buildPeriodButton('Monthly Patterns', 'monthly'),
        const SizedBox(width: 8),
        _buildPeriodButton('Annual Aggregate', 'yearly'),
      ],
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedPeriod = value;
          });
          _loadSummary();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFF1E293B)
              : const Color(0xFF0F172A),
          foregroundColor: isSelected
              ? const Color(0xFF60A5FA)
              : const Color(0xFF64748B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF334155),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildRoleContextFilters() {
    final user = _db.currentUser;
    if (user == null) return const SizedBox();

    if (user.role == UserRole.parent) {
      final children = user.students ?? [];
      if (children.isEmpty) return const SizedBox();
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            const Icon(Icons.child_care, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 12),
            const Text(
              'Child Context:',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StudentModel>(
                    value: _parentSelectedChild,
                    hint: const Text(
                      'Select a child',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    dropdownColor: const Color(0xFF1E293B),
                    isExpanded: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    items: children.map((c) {
                      return DropdownMenuItem<StudentModel>(
                        value: c,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (newChild) {
                      setState(() {
                        _parentSelectedChild = newChild;
                      });
                      _loadSummary();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (user.role == UserRole.adviser) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFF2563EB),
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text(
              'Section Scope:',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              user.assignedSection ?? 'Assigned Section',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Authorized Section',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (user.role == UserRole.principal ||
        user.role == UserRole.osd ||
        user.role == UserRole.ministrong_tagasubaybay) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.class_outlined,
              color: Color(0xFF2563EB),
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text(
              'Section Scope:',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    hint: const Text(
                      'Campus-Wide / All Sections',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    dropdownColor: const Color(0xFF1E293B),
                    isExpanded: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Campus-Wide / All Sections'),
                      ),
                      ..._classSections.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Text(c),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedClass = val;
                      });
                      _loadSummary();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildHeaderControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AGGREGATION TIMESTAMP',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _lastGenerated,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _loadSummary(refresh: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: const Color(0xFF60A5FA),
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(
            'Re-aggregate Trends',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsVisualizerCard() {
    final total = _stats!['total_cases'] ?? 0;
    final verbal = _stats!['verbal_count'] ?? 0;
    final cyber = _stats!['cyber_count'] ?? 0;
    final physical = _stats!['physical_count'] ?? 0;
    final relational = _stats!['relational_count'] ?? 0;

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RESOLVED INCIDENT PATTERNS',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatLabel(
                  'Resolved Total',
                  total.toString(),
                  Colors.white,
                ),
                _buildStatLabel(
                  'Verbal',
                  verbal.toString(),
                  const Color(0xFFFBBF24),
                ),
                _buildStatLabel(
                  'Cyber',
                  cyber.toString(),
                  const Color(0xFF60A5FA),
                ),
                _buildStatLabel(
                  'Physical',
                  physical.toString(),
                  const Color(0xFFF87171),
                ),
                _buildStatLabel(
                  'Relational',
                  relational.toString(),
                  const Color(0xFFA78BFA),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 12),
            _buildStatProgressBar(
              'Verbal Infractions',
              verbal,
              total,
              const Color(0xFFFBBF24),
            ),
            const SizedBox(height: 10),
            _buildStatProgressBar(
              'Cyber Infractions',
              cyber,
              total,
              const Color(0xFF60A5FA),
            ),
            const SizedBox(height: 10),
            _buildStatProgressBar(
              'Physical Infractions',
              physical,
              total,
              const Color(0xFFF87171),
            ),
            const SizedBox(height: 10),
            _buildStatProgressBar(
              'Social / Relational Exclusion',
              relational,
              total,
              const Color(0xFFA78BFA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatLabel(String title, String val, Color valColor) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStatProgressBar(String label, int val, int total, Color color) {
    final double percent = total > 0 ? (val / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(percent * 100).round()}% ($val)',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent > 1.0 ? 1.0 : percent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MarkdownText extends StatelessWidget {
  final String text;
  const MarkdownText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> children = [];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('### ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('#### ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              line.substring(5),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF60A5FA),
                  ),
                ),
                Expanded(child: _buildRichText(line.substring(2))),
              ],
            ),
          ),
        );
      } else if (line.startsWith('> ')) {
        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: const Border(
                left: BorderSide(color: Color(0xFF3B82F6), width: 4),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _buildRichText(line.substring(2)),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: _buildRichText(line),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildRichText(String rawText) {
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regExp.allMatches(rawText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: rawText.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < rawText.length) {
      spans.add(TextSpan(text: rawText.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}
