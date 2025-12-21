import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key});

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> familyMembers = [];
  bool isLoading = true;
  bool isAdmin = false;
  String? familyId;

  @override
  void initState() {
    super.initState();
    fetchFamilyMembers();
  }

  Future<void> fetchFamilyMembers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final adminFamilyRes = await supabase
          .from('families')
          .select()
          .eq('admin_user_id', user.id)
          .maybeSingle();

      Map<String, dynamic>? familyMap;

      if (adminFamilyRes != null) {
        familyMap = Map<String, dynamic>.from(adminFamilyRes);
        isAdmin = true;
      } else {
        final memberRes = await supabase
            .from('family_members')
            .select('family_id')
            .eq('email', user.email ?? '')
            .maybeSingle();

        if (memberRes == null) {
          setState(() {
            familyMembers = [];
            isLoading = false;
          });
          return;
        }

        final familyRes = await supabase
            .from('families')
            .select()
            .eq('id', memberRes['family_id'])
            .maybeSingle();

        if (familyRes == null) {
          setState(() => isLoading = false);
          return;
        }

        familyMap = Map<String, dynamic>.from(familyRes);
        isAdmin = false;
      }

      familyId = familyMap['id'];

      final membersRes = await supabase
          .from('family_members')
          .select('id, name, age, email, calorie_target')
          .eq('family_id', familyId!);

      if (!mounted) return;

      setState(() {
        familyMembers = List<Map<String, dynamic>>.from(membersRes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading family members: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '2000');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Family Member'),
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
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(labelText: 'Target Calories'),
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

              await supabase.from('family_members').insert({
                'family_id': familyId,
                'name': nameCtrl.text,
                'age': int.tryParse(ageCtrl.text) ?? 0,
                'email': emailCtrl.text,
                'calorie_target': int.tryParse(targetCtrl.text) ?? 2000,
              });

              if (!mounted) return;
              Navigator.pop(context);
              fetchFamilyMembers();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<int> _fetchTodayCaloriesByEmail(String email) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);

    final data = await supabase
        .from('calorie_logs')
        .select('calories, users!inner(email)')
        .eq('users.email', email)
        .gte('created_at', start.toIso8601String());

    return data.fold<int>(0, (sum, row) => sum + (row['calories'] as int));
  }

  void _showEditDialog(Map<String, dynamic> member) {
    final nameCtrl = TextEditingController(text: member['name']);
    final ageCtrl = TextEditingController(
      text: member['age']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(text: member['email']);
    final targetCtrl = TextEditingController(
      text: member['calorie_target']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: targetCtrl,
              decoration: const InputDecoration(labelText: 'Target Calories'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase
                  .from('family_members')
                  .update({
                    'name': nameCtrl.text,
                    'age': int.tryParse(ageCtrl.text) ?? 0,
                    'email': emailCtrl.text,
                    'calorie_target': int.tryParse(targetCtrl.text) ?? 2000,
                  })
                  .eq('id', member['id']);

              if (!mounted) return;
              Navigator.pop(context);
              fetchFamilyMembers();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final int targetCalories = member['calorie_target'] ?? 2000;

    return FutureBuilder<int>(
      future: _fetchTodayCaloriesByEmail(member['email']),
      builder: (context, snapshot) {
        final totalCalories = snapshot.data ?? 0;
        final double progress = targetCalories > 0
            ? (totalCalories / targetCalories).clamp(0.0, 1.0)
            : 0.0;

        return Dismissible(
          key: ValueKey(member['id']),
          direction: isAdmin
              ? DismissDirection.endToStart
              : DismissDirection.none,
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Member'),
                    content: const Text('Are you sure?'),
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
            await supabase
                .from('family_members')
                .delete()
                .eq('id', member['id']);
            fetchFamilyMembers();
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Color(0xFF7AC943),
                          ),
                          onPressed: () => _showEditDialog(member),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress, minHeight: 12),
                  const SizedBox(height: 8),
                  Text('$totalCalories / $targetCalories kcal'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.group_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No family members yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Start by adding your first family member\nand track calories together 💚',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
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
          : familyMembers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: familyMembers.length,
              itemBuilder: (_, i) => _buildMemberCard(familyMembers[i]),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF008B8B),
              onPressed: _showAddMemberDialog,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}
