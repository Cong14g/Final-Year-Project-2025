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
  final authService = AuthService();
  final supabase = Supabase.instance.client;

  String name = '';
  String email = '';
  String role = '';
  File? profileImage;
  bool isEditingName = false;
  final _nameController = TextEditingController();

  bool isInFamily = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkIfUserInFamily();
  }

  void _loadProfileData() {
    final user = supabase.auth.currentUser;
    if (!mounted) return;

    final metadata = user?.userMetadata;

    setState(() {
      email = user?.email ?? '';
      name = metadata?['first_name'] ?? 'User';
      role = metadata?['role'] ?? 'user';
      _nameController.text = name;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => profileImage = File(picked.path));
    }
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
    ).showSnackBar(const SnackBar(content: Text("Name updated successfully")));
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _checkIfUserInFamily() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isAdmin = await supabase
        .from('families')
        .select('id')
        .eq('admin_user_id', user.id)
        .maybeSingle();

    if (isAdmin != null) {
      setState(() => isInFamily = true);
      return;
    }

    final isMember = await supabase
        .from('family_members')
        .select('id')
        .eq('email', user.email ?? '')
        .maybeSingle();

    if (isMember != null) {
      setState(() => isInFamily = true);
    }
  }

  void _goToFamilyRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FamilyRegisterPage()),
    );
  }

  void _goToFeedbackPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackPage()),
    );
  }

  Widget _buildAvatar() {
    if (profileImage != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(profileImage!),
      );
    }

    final initials = name.isNotEmpty
        ? name.trim().split(" ").map((e) => e[0]).take(2).join()
        : "U";

    return CircleAvatar(
      radius: 50,
      backgroundColor: const Color(0xFF008B8B),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(fontSize: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditableName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Name", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF008B8B)),
              onPressed: _updateName,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRegisterAndFeedbackButtons() {
    return Row(
      children: [
        if (!isInFamily) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: _goToFamilyRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008B8B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                "Register Family",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: _goToFeedbackPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008B8B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              "Feedback",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008B8B),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildAvatar(),
            TextButton(
              onPressed: _pickImage,
              child: const Text(
                "Change Photo",
                style: TextStyle(color: Color(0xFF008B8B)),
              ),
            ),
            const SizedBox(height: 20),

            isEditingName
                ? _buildEditableName()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildInfoField("Name", name)),
                      IconButton(
                        onPressed: () {
                          setState(() => isEditingName = true);
                        },
                        icon: const Icon(Icons.edit, color: Color(0xFF008B8B)),
                      ),
                    ],
                  ),

            _buildInfoField("Email", email),

            const SizedBox(height: 10),
            _buildRegisterAndFeedbackButtons(),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  "Logout",
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
