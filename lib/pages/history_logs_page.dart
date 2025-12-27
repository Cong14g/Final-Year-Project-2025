import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryLogsPage extends StatefulWidget {
  const HistoryLogsPage({super.key});

  @override
  State<HistoryLogsPage> createState() => _HistoryLogsPageState();
}

class _HistoryLogsPageState extends State<HistoryLogsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  Map<String, List<dynamic>> groupedLogs = {};
  String? familyMemberId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFamilyMemberAndHistory();
  }

  DateTime _onlyDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  String _sectionTitle(DateTime logDate) {
    final today = _onlyDate(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (logDate == today) return 'Today';
    if (logDate == yesterday) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${logDate.day} ${months[logDate.month - 1]} ${logDate.year}';
  }

  Future<void> _loadFamilyMemberAndHistory() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) return;

    final member = await supabase
        .from('family_members')
        .select('id')
        .eq('email', user.email!)
        .maybeSingle();

    if (member == null) {
      setState(() => isLoading = false);
      return;
    }

    familyMemberId = member['id'];

    final data = await supabase
        .from('calorie_logs')
        .select()
        .eq('family_member_id', familyMemberId!)
        .order('timestamp', ascending: false);

    final Map<String, List<dynamic>> temp = {};

    for (final log in data) {
      final date = _onlyDate(DateTime.parse(log['timestamp']).toLocal());
      final section = _sectionTitle(date);

      temp.putIfAbsent(section, () => []);
      temp[section]!.add(log);
    }

    if (mounted) {
      setState(() {
        groupedLogs = temp;
        isLoading = false;
      });
    }
  }

  /// 🔥 Delete from Supabase
  Future<void> _deleteLog(String logId) async {
    await supabase.from('calorie_logs').delete().eq('id', logId);

    _loadFamilyMemberAndHistory();
  }

  /// 🔔 Confirm dialog
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete food log'),
            content: const Text('Are you sure you want to delete this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFF008B8B),
        centerTitle: true,
        title: const Text('History Log', style: TextStyle(color: Colors.white)),
      ),

      body: RefreshIndicator(
        onRefresh: _loadFamilyMemberAndHistory,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : groupedLogs.isEmpty
            ? const Center(
                child: Text(
                  'No history found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Center(
                    child: Text(
                      'My Calories',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008B8B),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ...groupedLogs.entries.map((entry) {
                    final section = entry.key;
                    final logs = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// SECTION HEADER
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              section,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        /// FOOD ITEMS (Swipe to delete)
                        ...logs.map((log) {
                          return Dismissible(
                            key: ValueKey(log['id']),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(context),
                            onDismissed: (_) => _deleteLog(log['id']),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log['food_name'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    '${log['calories']} kcal',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7AC943),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ],
              ),
      ),
    );
  }
}
