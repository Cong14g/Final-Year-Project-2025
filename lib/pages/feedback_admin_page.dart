import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allFeedback = [];
  List<Map<String, dynamic>> filteredFeedback = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFeedback();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchFeedback() async {
    setState(() => isLoading = true);

    try {
      final res = await supabase
          .from('feedback')
          .select('id, email, feedback, created_at')
          .order('created_at', ascending: false);

      if (!mounted) return;

      allFeedback = List<Map<String, dynamic>>.from(res);
      filteredFeedback = allFeedback;

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Feedback fetch error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterByEmail(String value) {
    final keyword = value.toLowerCase();

    setState(() {
      filteredFeedback = allFeedback.where((item) {
        final email = (item['email'] ?? '').toString().toLowerCase();
        return email.contains(keyword);
      }).toList();
    });
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Feedback',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackRow(Map<String, dynamic> item) {
    final date = DateTime.parse(item['created_at']).toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(item['email'] ?? '-')),
          Expanded(
            flex: 1,
            child: Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(flex: 3, child: Text(item['feedback'] ?? '')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF008B8B),
        title: const Text(
          'EatWise User Feedback Center',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monitor insights and track user experiences effortlessly',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: _filterByEmail,
            ),

            const SizedBox(height: 20),
            _buildHeaderRow(),
            const SizedBox(height: 8),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFeedback.isEmpty
                  ? const Center(
                      child: Text(
                        'No feedback found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredFeedback.length,
                      itemBuilder: (_, i) =>
                          _buildFeedbackRow(filteredFeedback[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
