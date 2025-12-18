import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'profile_page.dart';
import 'family_members_page.dart';

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
  int targetCalories = 0;

  @override
  void initState() {
    super.initState();
    fetchPosts();
    fetchCalorieDashboard();
  }

  // ---------------- POSTS ----------------

  Future<void> fetchPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select()
          .lte('publish_at', DateTime.now().toIso8601String())
          .order('publish_at', ascending: false);

      if (!mounted) return;

      setState(() {
        posts = List<Map<String, dynamic>>.from(response);
        isLoadingPosts = false;
      });
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => isLoadingPosts = false);
    }
  }

  // ---------------- DASHBOARDASHBOARD ----------------

  Future<void> fetchCalorieDashboard() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final targetRes = await supabase
          .from('daily_targets')
          .select('target_calories')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      targetCalories = targetRes?['target_calories'] ?? 2000;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );

      final logRes = await supabase
          .from('calorie_logs')
          .select()
          .eq('user_id', userId)
          .gte('timestamp', todayStart.toIso8601String())
          .lte('timestamp', todayEnd.toIso8601String())
          .order('timestamp', ascending: false);

      todayLogs = List<Map<String, dynamic>>.from(logRes);
      totalCaloriesToday = todayLogs.fold(0, (sum, log) {
        final cal = log['calories'];
        final parsed = cal is int ? cal : int.tryParse(cal.toString()) ?? 0;
        return sum + parsed;
      });

      if (mounted) setState(() => isLoadingDashboard = false);
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) setState(() => isLoadingDashboard = false);
    }
  }

  Future<String?> _getFirstName() async {
    final user = supabase.auth.currentUser;
    return user?.userMetadata?['first_name'] ?? 'User';
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      setState(() => isLoadingDashboard = true);
      fetchCalorieDashboard();
    }
  }

  // ---------------- UI ----------------

  Widget _buildDashboardCard() {
    final percentage = targetCalories > 0
        ? totalCaloriesToday / targetCalories
        : 0.0;
    final clampedPercent = percentage.clamp(0.0, 1.0);
    final caloriesLeft = targetCalories - totalCaloriesToday;

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
                  value: clampedPercent,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("of $targetCalories kcal"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            caloriesLeft >= 0
                ? "$caloriesLeft kcal left"
                : "${-caloriesLeft} kcal over",
            style: TextStyle(
              fontSize: 16,
              color: caloriesLeft >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return FutureBuilder<String?>(
      future: _getFirstName(),
      builder: (context, snapshot) {
        final firstName = snapshot.data ?? 'User';

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
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'Welcome back, $firstName 👋',
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
                  "📢 Latest Posts",
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
                    ? const Text("No posts yet.")
                    : Column(
                        children: posts.map((post) {
                          final publishAt =
                              DateTime.tryParse(post['publish_at'] ?? '') ??
                              DateTime.now();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post['title'] ?? 'Untitled',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(post['content'] ?? ''),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: const [
                                        Text(
                                          "👍",
                                          style: TextStyle(fontSize: 22),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "❤️",
                                          style: TextStyle(fontSize: 22),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Published: ${publishAt.toLocal()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraTab() {
    return const Scaffold(
      body: Center(
        child: Text('Camera coming soon 📷', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      _buildCameraTab(),
      const FamilyMembersPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: const Color(0xFF008B8B),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Family'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
