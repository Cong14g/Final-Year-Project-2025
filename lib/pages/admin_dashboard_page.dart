import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eatwiseapp/pages/login_page.dart';
import 'package:eatwiseapp/pages/admin_post_page.dart';
import 'package:eatwiseapp/pages/admin_user_management_page.dart';
import 'package:eatwiseapp/pages/feedback_admin_page.dart'; // ✅ ADD THIS

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  String adminInitial = 'A';
  String adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    final firstName = user?.userMetadata?['first_name'] ?? 'Admin';
    adminName = firstName;
    adminInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A';
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _buildDashboardButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.green, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal.shade700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
        centerTitle: true,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset('assets/logo.png', height: 32),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF008B8B),
              child: Text(
                adminInitial,
                style: const TextStyle(fontSize: 36, color: Colors.white),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              adminName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            _buildDashboardButton(
              "User",
              "Manage users",
              Icons.person_outline,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminUserManagementPage(),
                  ),
                );
              },
            ),

            _buildDashboardButton(
              "Post",
              "Create, edit, or publish learning materials",
              Icons.article_outlined,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPostPage()),
                );
              },
            ),

            _buildDashboardButton(
              "Feedback",
              "See feedback activity",
              Icons.feedback_outlined,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminFeedbackPage()),
                );
              },
            ),

            const Spacer(),

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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
