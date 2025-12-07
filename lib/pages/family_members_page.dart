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

  @override
  void initState() {
    super.initState();
    fetchFamilyMembers();
  }

  Future<void> fetchFamilyMembers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      var familyResponse = await supabase
          .from('families')
          .select()
          .eq('admin_user_id', user.id)
          .maybeSingle();

      if (familyResponse == null) {
        final memberResponse = await supabase
            .from('family_members')
            .select('family_id')
            .eq('email', user.email ?? '')
            .maybeSingle();

        if (memberResponse != null) {
          familyResponse = await supabase
              .from('families')
              .select()
              .eq('id', memberResponse['family_id'])
              .maybeSingle();
        }
      }

      if (familyResponse == null) {
        setState(() {
          familyMembers = [];
          isLoading = false;
        });
        return;
      }

      final familyId = familyResponse['id'];
      final isCurrentUserAdmin = familyResponse['admin_user_id'] == user.id;

      final membersResponse = await supabase
          .from('family_members')
          .select('id, name, age, email')
          .eq('family_id', familyId);

      if (!mounted) return;

      setState(() {
        familyMembers = List<Map<String, dynamic>>.from(membersResponse);
        isAdmin = isCurrentUserAdmin;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Error loading family members: $e');
    }
  }

  void _showAddMemberDialog() {
    String name = '';
    String age = '';
    String email = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Family Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (value) => name = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                onChanged: (value) => age = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (value) => email = value,
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
                await _addFamilyMember(name, age, email);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addFamilyMember(String name, String age, String email) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final family = await supabase
          .from('families')
          .select('id')
          .eq('admin_user_id', user.id)
          .maybeSingle();

      if (family == null) return;
      final familyId = family['id'];

      await supabase.from('family_members').insert({
        'family_id': familyId,
        'name': name,
        'age': int.tryParse(age) ?? 0,
        'email': email,
      });

      await fetchFamilyMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added successfully.')),
      );
    } catch (e) {
      debugPrint('Add member error: $e');
    }
  }

  void _showEditMemberDialog(Map<String, dynamic> member) {
    final nameController = TextEditingController(text: member['name'] ?? '');
    final ageController = TextEditingController(
      text: member['age'] != null ? member['age'].toString() : '',
    );
    final emailController = TextEditingController(text: member['email'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Family Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
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
                await _updateFamilyMember(
                  member['id'],
                  nameController.text,
                  ageController.text,
                  emailController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFamilyMember(
    dynamic memberId,
    String name,
    String age,
    String email,
  ) async {
    final String? id = memberId?.toString();
    if (id == null || id.isEmpty) return;

    try {
      await supabase
          .from('family_members')
          .update({'name': name, 'age': int.tryParse(age) ?? 0, 'email': email})
          .eq('id', id);

      await fetchFamilyMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member successfully added')),
      );
    } catch (e) {
      debugPrint('Update member error: $e');
    }
  }

  Future<void> deleteMember(dynamic memberId) async {
    final String? id = memberId?.toString();
    if (id == null || id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Member"),
        content: const Text("Are you sure you want to delete this member?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('family_members').delete().eq('id', id);
      await fetchFamilyMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member successfully deleted")),
      );
    } catch (e) {
      debugPrint('Error deleting member: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting member: $e")));
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF008B8B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFF008B8B),
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Age: ${member['age'] ?? 'N/A'}"),
                  Text("Email: ${member['email'] ?? 'N/A'}"),
                ],
              ),
            ),
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () => _showEditMemberDialog(member),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteMember(member['id']),
              ),
            ],
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
          "Family Members",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF008B8B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : familyMembers.isEmpty
          ? const Center(child: Text("No family members found."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: familyMembers.length,
              itemBuilder: (context, index) {
                return _buildMemberCard(familyMembers[index]);
              },
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
