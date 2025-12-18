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
  String role = '';
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

  // ================= PROFILE =================

  void _loadProfileData() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata;

    setState(() {
      name = metadata?['first_name'] ?? 'User';
      role = metadata?['role'] ?? 'user';
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated successfully')));
  }

  // ================= CALORIE TARGET =================

  Future<void> _loadCalorieTarget() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => isLoadingTarget = false);
      return;
    }

    try {
      final res = await supabase
          .from('daily_targets')
          .select('target_calories')
          .eq('user_id', user.id)
          .maybeSingle();

      if (res != null && res['target_calories'] != null) {
        targetCalories = res['target_calories'];
        _targetController.text = targetCalories.toString();
      }
    } finally {
      if (mounted) setState(() => isLoadingTarget = false);
    }
  }

  Future<void> _saveTargetCalories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final parsed = int.tryParse(_targetController.text.trim());
    if (parsed == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid number')));
      return;
    }

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
        const SnackBar(content: Text('Daily calorie target saved')),
      );
    } finally {
      if (mounted) setState(() => isSavingTarget = false);
    }
  }

  // ================= FAMILY =================

  Future<void> _checkIfUserInFamily() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final adminRes = await supabase
        .from('families')
        .select('id')
        .eq('admin_user_id', user.id)
        .maybeSingle();

    if (adminRes != null) {
      setState(() => isInFamily = true);
      return;
    }

    final memberRes = await supabase
        .from('family_members')
        .select('id')
        .eq('email', user.email ?? '')
        .maybeSingle();

    if (memberRes != null) {
      setState(() => isInFamily = true);
    }
  }

  // ================= AVATAR =================

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => profileImage = File(picked.path));
    }
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: const Color(0xFF008B8B),
      backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
      child: profileImage == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 32, color: Colors.white),
            )
          : null,
    );
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await authService.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ================= UI =================

  Widget _buildCalorieTargetField() {
    if (isLoadingTarget) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Calorie Target'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter daily calorie goal',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: isSavingTarget ? null : _saveTargetCalories,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008B8B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: isSavingTarget
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
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
            _buildAvatar(),
            TextButton(
              onPressed: _pickImage,
              child: const Text('Change Photo'),
            ),
            const SizedBox(height: 16),

            // Name + Email
            isEditingName
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _updateName,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => setState(() => isEditingName = true),
                      ),
                    ],
                  ),

            const SizedBox(height: 16),
            _buildCalorieTargetField(),
            const SizedBox(height: 24),

            // ✅ Register Family (only if NOT in family)
            if (!isInFamily)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC943),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FamilyRegisterPage(),
                    ),
                  ),
                  child: const Text(
                    'Register Family',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

            if (!isInFamily) const SizedBox(height: 12),

            // Feedback
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008B8B),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackPage()),
                ),
                child: const Text(
                  'Feedback',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _logout,
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
