import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class DuplicateManagerScreen extends StatefulWidget {
  const DuplicateManagerScreen({super.key});

  @override
  State<DuplicateManagerScreen> createState() => _DuplicateManagerScreenState();
}

class _DuplicateManagerScreenState extends State<DuplicateManagerScreen> {
  final _db = DatabaseService();
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _flags = [];

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _db.getDuplicateFlags();
      setState(() {
        _flags = data;
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

  Future<void> _handleResolve(String id, String status) async {
    try {
      setState(() => _isLoading = true);
      await _db.resolveDuplicateFlag(id, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully marked flag as $status.')),
      );
      _loadFlags();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleDeleteAccount(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This will permanently delete the duplicate parent account registration associated with this flag. Are you sure you want to proceed?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _db.deleteDuplicateAccount(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duplicate parent account and associated flags deleted successfully.')),
      );
      _loadFlags();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Duplicate Accounts Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading && _flags.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadFlags,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF451A03),
                              border: Border.all(color: const Color(0xFF78350F)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 13),
                            ),
                          ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_flags.length} Duplicate Detection Flag(s)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
                              onPressed: _loadFlags,
                              tooltip: 'Refresh list',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_flags.isEmpty)
                          const Card(
                            color: Color(0xFF1E293B),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 48.0),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
                                  SizedBox(height: 16),
                                  Text(
                                    'No duplicate signup conflicts detected.',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._flags.map((flag) => _buildFlagCard(flag)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFlagCard(Map<String, dynamic> flag) {
    final status = flag['status'] ?? 'Pending';
    final reason = flag['reason'] ?? 'Email and Student Details Conflict';
    final name = flag['parent_name'] ?? 'Unknown';
    final email = flag['email'] ?? 'Unknown';
    final studentName = flag['student_name'] ?? 'Unknown';
    final sectionName = flag['section_name'] ?? 'Unknown';
    final createdAt = flag['created_at'] != null 
        ? DateTime.parse(flag['created_at']).toLocal() 
        : DateTime.now();
    final formattedDate = '${createdAt.month}/${createdAt.day}/${createdAt.year}';

    Color badgeColor = const Color(0xFF3B82F6);
    if (status == 'Resolved') badgeColor = const Color(0xFF10B981);
    if (status == 'Dismissed') badgeColor = const Color(0xFF64748B);

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Attempted Parent Name: $name',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Email Address: $email',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MATCHED DETAILS:', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 9)),
                  const SizedBox(height: 4),
                  Text('Student: $studentName', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text('Class: $sectionName', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 6),
                  Text('Flag Reason: $reason', style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (status == 'Pending') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _handleResolve(flag['id'].toString(), 'Dismissed'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Dismiss Flag', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _handleResolve(flag['id'].toString(), 'Resolved'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Mark Resolved', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleDeleteAccount(flag['id'].toString()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              )
            ] else ...[
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'This flag conflict has been resolved.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
