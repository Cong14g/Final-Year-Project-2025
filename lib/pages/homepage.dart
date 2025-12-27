import 'package:eatwiseapp/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'family_members_page.dart';
import 'camera_scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  int _selectedIndex = 0;

  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> todayLogs = [];

  bool isLoadingPosts = true;
  bool isLoadingDashboard = true;

  int totalCaloriesToday = 0;
  int targetCalories = 2000;

  String? familyMemberId;

  @override
  void initState() {
    super.initState();
    fetchPosts();
    fetchCalorieDashboard();
  }

  Future<void> fetchPosts() async {
    try {
      final res = await supabase
          .from('posts')
          .select()
          .lte('publish_at', DateTime.now().toIso8601String())
          .order('publish_at', ascending: false);

      if (!mounted) return;

      setState(() {
        posts = List<Map<String, dynamic>>.from(res);
        isLoadingPosts = false;
      });
    } catch (e) {
      debugPrint('Posts error: $e');
      if (mounted) setState(() => isLoadingPosts = false);
    }
  }

  Future<void> fetchCalorieDashboard() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) return;

      setState(() => isLoadingDashboard = true);

      final memberRes = await supabase
          .from('family_members')
          .select('id, calorie_target')
          .eq('email', user.email!)
          .maybeSingle();

      if (memberRes == null) {
        setState(() => isLoadingDashboard = false);
        return;
      }

      familyMemberId = memberRes['id'];
      targetCalories = memberRes['calorie_target'] ?? 2000;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final logsRes = await supabase
          .from('calorie_logs')
          .select('calories')
          .eq('family_member_id', familyMemberId!)
          .gte('created_at', todayStart.toIso8601String());

      todayLogs = List<Map<String, dynamic>>.from(logsRes);

      totalCaloriesToday = todayLogs.fold<int>(
        0,
        (sum, log) => sum + (log['calories'] as int),
      );

      if (mounted) setState(() => isLoadingDashboard = false);
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => isLoadingDashboard = false);
    }
  }

  Future<String> _getFirstName() async {
    final user = supabase.auth.currentUser;
    return user?.userMetadata?['first_name'] ?? 'User';
  }

  Future<void> _onNavTap(int index) async {
    if (index == 1) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScanPage()),
      );

      if (result == true) {
        await fetchCalorieDashboard();
      }
      return;
    }

    setState(() => _selectedIndex = index);

    if (index == 0) {
      await fetchCalorieDashboard();
    }
  }

  Widget _buildDashboardCard() {
    final percent = targetCalories > 0
        ? (totalCaloriesToday / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final left = targetCalories - totalCaloriesToday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          const Text(
            "🔥 Daily Calorie Progress",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[300],
                  color: Colors.teal,
                ),
              ),
              Column(
                children: [
                  Text(
                    "$totalCaloriesToday kcal",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Text("of $targetCalories kcal"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            left >= 0 ? "$left kcal left" : "${-left} kcal over",
            style: TextStyle(
              fontSize: 16,
              color: left >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return FutureBuilder<String>(
      future: _getFirstName(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'User';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF008B8B),
            title: const Text(
              'EatWise Home',
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Welcome back, $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF008B8B),
                ),
              ),
              const SizedBox(height: 24),

              isLoadingDashboard
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDashboardCard(),

              const SizedBox(height: 32),

              const Text(
                '📢 Latest Posts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 12),

              isLoadingPosts
                  ? const Center(child: CircularProgressIndicator())
                  : posts.isEmpty
                  ? const Text('No posts yet.')
                  : Column(
                      children: posts
                          .map(
                            (post) => PostCard(post: post, supabase: supabase),
                          )
                          .toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(Icons.home, 0),
            _navIcon(Icons.qr_code_scanner, 1),
            _navIcon(Icons.group, 2),
            _navIcon(Icons.person, 3),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final isActive = _selectedIndex == index;
    return InkWell(
      onTap: () => _onNavTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? Colors.green : Colors.grey),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      const SizedBox(),
      const FamilyMembersPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: tabs[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
