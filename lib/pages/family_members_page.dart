import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key});

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> members = [];
  bool isLoading = true;
  bool isAdmin = false;
  String? familyId;

  final relationships = [
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Spouse',
    'Guardian',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final adminFamily = await supabase
          .from('families')
          .select()
          .eq('admin_user_id', user.id)
          .maybeSingle();

      if (adminFamily != null) {
        familyId = adminFamily['id'];
        isAdmin = true;
      } else {
        final member = await supabase
            .from('family_members')
            .select('family_id')
            .eq('email', user.email!)
            .maybeSingle();

        if (member == null) {
          setState(() {
            members = [];
            isLoading = false;
          });
          return;
        }

        familyId = member['family_id'];
        isAdmin = false;
      }

      final data = await supabase
          .from('family_members')
          .select()
          .eq('family_id', familyId!)
          .order('is_admin', ascending: false);

      setState(() {
        members = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Fetch members error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTodayLogs(String memberId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    final res = await supabase
        .from('calorie_logs')
        .select('food_name, calories, created_at')
        .eq('family_member_id', memberId)
        .gte('created_at', start.toIso8601String())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  int _sumCalories(List<Map<String, dynamic>> logs) {
    return logs.fold<int>(0, (sum, l) => sum + (l['calories'] as int));
  }

  Color _progressColor(double rawProgress) {
    if (rawProgress <= 0.7) {
      return Colors.green;
    } else if (rawProgress <= 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _openMemberDialog({Map<String, dynamic>? member}) {
    final nameCtrl = TextEditingController(text: member?['name']);
    final ageCtrl = TextEditingController(
      text: member?['age']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(text: member?['email']);
    final calorieCtrl = TextEditingController(
      text: member?['calorie_target']?.toString() ?? '2000',
    );

    String? relationship = member?['relationship'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          member == null ? 'Add Family Member' : 'Edit Family Member',
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: ageCtrl,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => relationship = v,
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: calorieCtrl,
                decoration: const InputDecoration(labelText: 'Calorie Target'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (familyId == null) return;

              final payload = {
                'family_id': familyId,
                'name': nameCtrl.text,
                'age': int.tryParse(ageCtrl.text),
                'email': emailCtrl.text,
                'relationship': relationship,
                'calorie_target': int.tryParse(calorieCtrl.text) ?? 2000,
              };

              if (member == null) {
                payload['is_admin'] = false;
                await supabase.from('family_members').insert(payload);
              } else {
                await supabase
                    .from('family_members')
                    .update(payload)
                    .eq('id', member['id']);
              }

              if (!mounted) return;
              Navigator.pop(context);
              fetchMembers();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m) {
    final target = m['calorie_target'] ?? 2000;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTodayLogs(m['id']),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final total = _sumCalories(logs);

        final rawProgress = target > 0 ? total / target : 0.0;
        final barValue = rawProgress.clamp(0.0, 1.0);

        return Dismissible(
          key: ValueKey(m['id']),
          direction: isAdmin && m['is_admin'] != true
              ? DismissDirection.endToStart
              : DismissDirection.none,
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Member'),
                    content: const Text(
                      'Are you sure you want to remove this member?',
                    ),
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
          },
          onDismissed: (_) async {
            await supabase.from('family_members').delete().eq('id', m['id']);
            fetchMembers();
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF008B8B),
                child: Text(m['name'][0].toUpperCase()),
              ),
              title: Row(
                children: [
                  Text(
                    m['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (m['is_admin'] == true)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: barValue,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(
                      _progressColor(rawProgress),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$total / $target kcal'),
                ],
              ),
              trailing: isAdmin
                  ? IconButton(
                      icon: const Icon(Icons.edit, color: Colors.green),
                      onPressed: () => _openMemberDialog(member: m),
                    )
                  : null,
              children: logs.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No logs today',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ]
                  : logs.map((log) {
                      final time = DateTime.parse(log['created_at']).toLocal();
                      return ListTile(
                        leading: const Icon(Icons.fastfood),
                        title: Text(log['food_name']),
                        subtitle: Text(
                          '${log['calories']} kcal • '
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}',
                        ),
                      );
                    }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Family Member Calorie Intake',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF008B8B),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
          ? const Center(child: Text('No family members yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (_, i) => _buildMemberCard(members[i]),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF7AC943),
              onPressed: () => _openMemberDialog(),
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}
