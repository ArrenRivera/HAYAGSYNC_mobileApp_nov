import 'package:flutter/material.dart';
import '../staff/staff_dashboard.dart';
import '../parent/parent_dashboard.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class TermsStorage {
  static Future<bool> isAccepted(String userId) async {
    try {
      return await DatabaseService().hasAcceptedTerms(userId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> accept(String userId) async {
    await DatabaseService().recordTermsAcceptance(userId);
  }

  static Future<void> clear(String userId) async {
    try {
      await DatabaseService().clearTermsAcceptance(userId);
    } catch (_) {}
  }
}

class TermsScreen extends StatefulWidget {
  final UserModel user;

  const TermsScreen({super.key, required this.user});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _db = DatabaseService();

  Future<void> _handleAccept() async {
    try {
      await TermsStorage.accept(widget.user.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your consent to Supabase: $e')),
      );
      return;
    }
    if (!mounted) return;

    if (widget.user.role == UserRole.parent) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentDashboard()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StaffDashboard()),
      );
    }
  }

  void _handleDecline() {
    _db.logout();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Color(0xFF818CF8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Agreement',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Comprehensive Terms & Conditions of Service',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ComprehensiveTermsWidget(
                        showDecline: true,
                        onAccept: _handleAccept,
                        onDecline: _handleDecline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ComprehensiveTermsWidget extends StatefulWidget {
  final bool showDecline;
  final VoidCallback onAccept;
  final VoidCallback? onDecline;

  const ComprehensiveTermsWidget({
    super.key,
    required this.showDecline,
    required this.onAccept,
    this.onDecline,
  });

  @override
  State<ComprehensiveTermsWidget> createState() =>
      _ComprehensiveTermsWidgetState();
}

class _ComprehensiveTermsWidgetState extends State<ComprehensiveTermsWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreeToCheckbox = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      // Triggers when within 40px of bottom, works well across devices
      if (currentScroll >= (maxScroll - 40)) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The readable text scroll area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HAYAGSYNC COMPREHENSIVE USER AGREEMENT & TERMS OF SERVICE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildParagraph(
                      'This Agreement governs the use of the HAYAGSYNC Anti-Bullying reporting, monitoring, and coordination application. By accessing this platform, all users—including parents/guardians, school advisers, principals, Ministrong Tagasubaybay, and Office of Student Discipline (OSD) officers—agree to follow these comprehensive guidelines and policies.',
                    ),
                    _buildSectionTitle('1. System Purpose & Safe Environment'),
                    _buildParagraph(
                      'The primary purpose of HAYAGSYNC is to provide a safe, secure, and confidential digital environment for reporting, monitoring, and coordinating school-level responses to student bullying incidents. The platform is designed to promote transparency, maintain clear timeline logs, and coordinate resolution schedules between parents and authorized school personnel.',
                    ),
                    _buildSectionTitle(
                      '2. Prohibited Behaviors & Anti-Bullying Rules',
                    ),
                    _buildParagraph(
                      'Under this agreement, the school strictly prohibits all forms of bullying and harassment. Prohibited behaviors include, but are not limited to:\n'
                      '• Physical Bullying: Hitting, shoving, kicking, punching, or any form of physical violence or coercion.\n'
                      '• Verbal Bullying: Name-calling, persistent teasing, mocking, verbal threats, and derogatory remarks.\n'
                      '• Cyberbullying: Harassment, sending threatening or offensive messages, sharing non-consensual images, or writing defamatory statements on online chats, social media, or other digital spaces.\n'
                      '• Social and Relational Bullying: Deliberate social exclusion, spreading malicious rumors, and damaging a student\'s social standing.',
                    ),
                    _buildSectionTitle(
                      '3. Legal Reference: Anti-Bullying Act of 2013 (RA 10627)',
                    ),
                    _buildParagraph(
                      'This platform and its policies are anchored upon Republic Act No. 10627, otherwise known as the Anti-Bullying Act of 2013, and its Implementing Rules and Regulations (IRR). All users are hereby notified that the school has a legal mandate to prevent, address, and report all instances of student bullying. System actions, escalations, and outcomes will comply with the statutory procedures defined under RA 10627.',
                    ),
                    _buildSectionTitle(
                      '4. Office of Student Discipline (OSD) Guidance Policies',
                    ),
                    _buildParagraph(
                      'HAYAGSYNC operates under the direct guidance and operational jurisdiction of the school\'s Office of Student Discipline (OSD). The reporting workflow enforces a structured escalation path:\n'
                      '• Initial Incident Filing: Filed by the Parent or Guardian.\n'
                      '• Preliminary Review: Handled by the assigned Section Adviser.\n'
                      '• Administrative Intervention: Escalated to the Principal if un-resolvable.\n'
                      '• OSD Jurisdiction: Final escalation to the OSD for formal investigation, counseling scheduling, and disciplinary implementation.\n'
                      'All meetings, agreements, and outcomes recorded on the platform are legally binding under OSD student behavior discipline policies.',
                    ),
                    _buildSectionTitle(
                      '5. Data Privacy & Compliance (RA 10173)',
                    ),
                    _buildParagraph(
                      'HAYAGSYNC is fully compliant with Republic Act No. 10173, also known as the Data Privacy Act of 2012. We take data confidentiality and protection seriously:\n'
                      '• All reported incident logs, student profile records, witness checklists, meeting calendars, and timeline logs are stored in encrypted databases.\n'
                      '• Access to case records is strictly restricted to assigned personnel (Adviser, Principal, Ministrong Tagasubaybay, OSD) and the parent who filed the case.\n'
                      '• Personally identifiable information (PII) of victims, witnesses, and alleged bullies is kept confidential and will not be shared externally.',
                    ),
                    _buildSectionTitle(
                      '6. Proper Handling of Uploaded Photos and Videos',
                    ),
                    _buildParagraph(
                      'To support incident resolution, parents are encouraged to upload photo or video evidence.\n'
                      '• Uploaded media files must be the original, unaltered files representing the incident.\n'
                      '• Authorized staff members are strictly prohibited from downloading, sharing, copying, resizing, cropping, or distributing uploaded evidence outside of the system.\n'
                      '• All evidence files are kept in protected storage with access logs to monitor viewing.',
                    ),
                    _buildSectionTitle(
                      '7. User Responsibilities & Acceptable Use',
                    ),
                    _buildParagraph(
                      'All users must act in good faith when utilizing HAYAGSYNC:\n'
                      '• Parents must compile truthful accounts, valid certificates, and real evidence.\n'
                      '• School staff must process cases objectively, follow timeline guidelines, and maintain absolute discretion.\n'
                      '• Users are responsible for maintaining the confidentiality of their credentials and must not share account access.',
                    ),
                    _buildSectionTitle(
                      '8. Consequences for Submitting False Reports',
                    ),
                    _buildParagraph(
                      'Filing fake, fabricated, malicious, or intentionally misleading reports is a serious violation of this agreement and school codes.\n'
                      '• Submitting false reports or uploading manipulated certificate documents will lead to immediate account suspension.\n'
                      '• Violators will face disciplinary review, including mandatory student counseling, parent consultation, warnings, community service, or formal suspension depending on severity.',
                    ),
                    _buildSectionTitle('9. School Disciplinary Procedures'),
                    _buildParagraph(
                      'Incidents logged in the system will undergo formal school review. Disciplinary resolutions and correction actions include:\n'
                      '• Warnings and behavior guidance agreements.\n'
                      '• Peer mediation and counselor-led conflict resolution sessions.\n'
                      '• Mandatory counseling sessions for the bully.\n'
                      '• School community service or short-term suspension.\n'
                      '• Expulsion for severe, repeated, or physical offences under OSD guidelines.',
                    ),
                    _buildSectionTitle(
                      '10. Consent for AI-Generated Summaries & Evidence Analysis',
                    ),
                    _buildParagraph(
                      'By checking the agreement below, you grant explicit consent for the system to process uploaded text, reports, and photos using AI verification algorithms. These tools automatically compile concise case summaries and scan uploaded files for potential digital manipulation or stock image signatures to expedite administrative triage.',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Scroll to Bottom Helper Badge
        if (!_hasScrolledToBottom)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 14,
                      color: Color(0xFF818CF8),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Scroll to bottom to unlock acceptance',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Checkbox row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreeToCheckbox,
              activeColor: const Color(0xFF6366F1),
              onChanged: _hasScrolledToBottom
                  ? (val) {
                      setState(() {
                        _agreeToCheckbox = val ?? false;
                      });
                    }
                  : null, // Disabled until scrolled to bottom
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  'I have read and agree to the Comprehensive Terms & Conditions.',
                  style: TextStyle(
                    color: _hasScrolledToBottom ? Colors.white : Colors.white24,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Action Buttons Row
        Row(
          children: [
            if (widget.showDecline) ...[
              Expanded(
                child: TextButton(
                  onPressed: widget.onDecline,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: (_hasScrolledToBottom && _agreeToCheckbox)
                    ? widget.onAccept
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  disabledForegroundColor: const Color(0xFF475569),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Accept & Proceed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18, // 18px for section headings
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 16, // 16px body font size
          height: 1.6, // 1.6 line height for legibility
        ),
      ),
    );
  }
}
