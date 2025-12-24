import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyRegisterPage extends StatefulWidget {
  const FamilyRegisterPage({super.key});

  @override
  State<FamilyRegisterPage> createState() => _FamilyRegisterPageState();
}

class _FamilyRegisterPageState extends State<FamilyRegisterPage> {
  final supabase = Supabase.instance.client;

  final _groupNameController = TextEditingController();
  final _adminNameController = TextEditingController();

  String? _adminRelationship;

  final List<String> relationships = [
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Spouse',
    'Grandparent',
    'Guardian',
    'Other',
  ];

  List<Map<String, dynamic>> members = [];

  void _addMemberField() {
    setState(() {
      members.add({'name': '', 'age': '', 'email': '', 'relationship': null});
    });
  }

  void _removeMemberField(int index) {
    setState(() {
      members.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final groupName = _groupNameController.text.trim();
    final adminName = _adminNameController.text.trim();
    final user = supabase.auth.currentUser;

    if (groupName.isEmpty ||
        adminName.isEmpty ||
        _adminRelationship == null ||
        user == null ||
        user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final adminEmail = user.email!;

    try {
      final familyInsert = await supabase
          .from('families')
          .insert({
            'group_name': groupName,
            'admin_user_id': user.id,
            'admin_name': adminName,
            'relationship': _adminRelationship,
            'email': adminEmail,
          })
          .select()
          .single();

      final familyId = familyInsert['id'];

      await supabase.from('family_members').insert({
        'family_id': familyId,
        'name': adminName,
        'email': adminEmail,
        'relationship': _adminRelationship,
        'daily_calories': 0,
        'calorie_target': 2000,
        'is_admin': true,
      });

      for (var member in members) {
        if ((member['name'] ?? '').toString().isEmpty ||
            member['relationship'] == null) {
          continue;
        }

        await supabase.from('family_members').insert({
          'family_id': familyId,
          'name': member['name'],
          'age': int.tryParse(member['age'] ?? ''),
          'email': member['email'],
          'relationship': member['relationship'],
          'daily_calories': 0,
          'calorie_target': 2000,
          'is_admin': false,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family registered successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Family register error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildMemberForm(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Member ${index + 1}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        TextField(
          decoration: const InputDecoration(labelText: "Member Name"),
          onChanged: (value) => members[index]['name'] = value,
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
                onChanged: (value) => members[index]['age'] = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: members[index]['relationship'],
                decoration: const InputDecoration(labelText: "Relationship"),
                items: relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => members[index]['relationship'] = value),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        TextField(
          decoration: const InputDecoration(labelText: "Member Email"),
          onChanged: (value) => members[index]['email'] = value,
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _removeMemberField(index),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ),

        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.green),
                ),
              ),

              const SizedBox(height: 12),
              Image.asset('assets/logo2.png', width: 80, height: 80),
              const SizedBox(height: 12),

              const Text(
                "Family Register",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00796B),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: "Family Group Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _adminNameController,
                decoration: const InputDecoration(
                  labelText: "Admin Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _adminRelationship,
                decoration: const InputDecoration(
                  labelText: "Relationship to Family",
                  border: OutlineInputBorder(),
                ),
                items: relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _adminRelationship = value),
              ),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Add Family Members",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              ...List.generate(members.length, _buildMemberForm),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _addMemberField,
                  child: const Text("+ Add Another Family Member"),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Register",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
