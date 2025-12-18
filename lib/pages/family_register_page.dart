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
  final _relationshipController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Map<String, dynamic>> members = [];

  void _addMemberField() {
    setState(() {
      members.add({'name': '', 'age': '', 'email': ''});
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
    final relationship = _relationshipController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final userId = supabase.auth.currentUser?.id;

    if (groupName.isEmpty ||
        adminName.isEmpty ||
        relationship.isEmpty ||
        adminEmail.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    try {
      final familyInsert = await supabase
          .from('families')
          .insert({
            'group_name': groupName,
            'admin_user_id': userId,
            'admin_name': adminName,
            'relationship': relationship,
            'email': adminEmail,
          })
          .select()
          .single();

      final familyId = familyInsert['id'];

      for (var member in members) {
        await supabase.from('family_members').insert({
          'family_id': familyId,
          'name': member['name'],
          'age': int.tryParse(member['age'] ?? '0'),
          'email': member['email'],
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family registered successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
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
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                decoration: const InputDecoration(labelText: "Member Name"),
                onChanged: (value) => members[index]['name'] = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
                onChanged: (value) => members[index]['age'] = value,
              ),
            ),
          ],
        ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.green),
                  ),
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
                  labelText: "Admin name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: "Relationship to Family",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _adminEmailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

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
                  child: const Text(
                    "+ Add Another Family Members",
                    style: TextStyle(color: Colors.blue),
                  ),
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
