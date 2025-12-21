import 'dart:io';
import 'package:eatwiseapp/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'family_register_page.dart';
import 'feedback_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final authService = AuthService();

  String name = '';
  String email = '';
  File? profileImage;

  bool isEditingName = false;
  final _nameController = TextEditingController();

  int? targetCalories;
  final _targetController = TextEditingController();
  bool isLoadingTarget = true;
  bool isSavingTarget = false;

  bool isInFamily = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadCalorieTarget();
    _checkIfUserInFamily();
  }

  void _loadProfileData() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      name = user.userMetadata?['first_name'] ?? 'User';
      email = user.email ?? '';
      _nameController.text = name;
    });
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.auth.updateUser(
      UserAttributes(data: {...?user.userMetadata, 'first_name': newName}),
    );

    if (!mounted) return;
    setState(() {
      name = newName;
      isEditingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Name updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _loadCalorieTarget() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoadingTarget = false);
      return;
    }

    try {
      final res = await supabase
          .from('daily_targets')
          .select('target_calories')
          .eq('user_id', user.id)
          .maybeSingle();

      if (res != null) {
        targetCalories = res['target_calories'];
        _targetController.text = targetCalories?.toString() ?? '';
      }
    } finally {
      if (mounted) setState(() => isLoadingTarget = false);
    }
  }

  Future<void> _saveTargetCalories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final parsed = int.tryParse(_targetController.text.trim());
    if (parsed == null) return;

    setState(() => isSavingTarget = true);

    try {
      await supabase.from('daily_targets').upsert({
        'user_id': user.id,
        'target_calories': parsed,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() => targetCalories = parsed);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily calorie target saved successfully'),
          backgroundColor: Color(0xFF7AC943), // app green
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => isSavingTarget = false);
    }
  }

  Future<void> _checkIfUserInFamily() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final admin = await supabase
        .from('families')
        .select('id')
        .eq('admin_user_id', user.id)
        .maybeSingle();

    if (admin != null) {
      setState(() => isInFamily = true);
      return;
    }

    final member = await supabase
        .from('family_members')
        .select('id')
        .eq('email', user.email ?? '')
        .maybeSingle();

    if (member != null) setState(() => isInFamily = true);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => profileImage = File(picked.path));
  }

  Widget _inputBox({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _fullButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008B8B),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF008B8B),
              backgroundImage: profileImage != null
                  ? FileImage(profileImage!)
                  : null,
              child: profileImage == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    )
                  : null,
            ),
            TextButton(onPressed: _pickImage, child: const Text('Edit')),

            const SizedBox(height: 16),

            _inputBox(
              label: 'Name',
              child: Row(
                children: [
                  Expanded(
                    child: isEditingName
                        ? TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                          )
                        : Text(name),
                  ),
                  IconButton(
                    icon: Icon(
                      isEditingName ? Icons.check : Icons.edit,
                      color: Colors.green,
                    ),
                    onPressed: isEditingName
                        ? _updateName
                        : () => setState(() => isEditingName = true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _inputBox(
              label: 'Email',
              child: Align(alignment: Alignment.centerLeft, child: Text(email)),
            ),

            const SizedBox(height: 24),

            _inputBox(
              label: 'Daily Calories Target',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isSavingTarget ? null : _saveTargetCalories,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008B8B),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (!isInFamily)
              Row(
                children: [
                  Expanded(
                    child: _fullButton(
                      'Register Family',
                      const Color(0xFF008B8B),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FamilyRegisterPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _fullButton(
                      'Feedback',
                      const Color(0xFF008B8B),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackPage()),
                      ),
                    ),
                  ),
                ],
              )
            else
              _fullButton(
                'Feedback',
                const Color(0xFF008B8B),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackPage()),
                ),
              ),

            const SizedBox(height: 12),

            _fullButton('Logout', Colors.red, () async {
              await authService.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            }),
          ],
        ),
      ),
    );
  }
}
