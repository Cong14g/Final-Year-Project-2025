import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPostPage extends StatefulWidget {
  const AdminPostPage({super.key});

  @override
  State<AdminPostPage> createState() => _AdminPostPageState();
}

class _AdminPostPageState extends State<AdminPostPage> {
  final supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool postNow = true;
  bool isLoading = false;

  List<Map<String, dynamic>> posts = [];
  String? editingPostId;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final res = await supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      posts = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> createOrUpdatePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and content cannot be empty")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      DateTime publishAt;

      if (postNow) {
        publishAt = DateTime.now();
      } else {
        if (selectedDate == null || selectedTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select date & time")),
          );
          setState(() => isLoading = false);
          return;
        }

        publishAt = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          selectedTime!.hour,
          selectedTime!.minute,
        );
      }

      if (editingPostId == null) {
        await supabase.from('posts').insert({
          'title': title,
          'content': content,
          'publish_at': publishAt.toIso8601String(),
          'created_by': supabase.auth.currentUser?.id,
        });
      } else {
        await supabase
            .from('posts')
            .update({
              'title': title,
              'content': content,
              'publish_at': publishAt.toIso8601String(),
            })
            .eq('id', editingPostId!);
      }

      _resetForm();
      await _fetchPosts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingPostId == null
                ? "Post published successfully!"
                : "Post updated successfully!",
          ),
          backgroundColor: const Color(0xFF008B8B),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deletePost(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase.from('posts').delete().eq('id', id);
    await _fetchPosts();
  }

  void _editPost(Map<String, dynamic> post) {
    setState(() {
      editingPostId = post['id'];
      _titleController.text = post['title'];
      _contentController.text = post['content'];
      postNow = true;
    });
  }

  void _resetForm() {
    setState(() {
      editingPostId = null;
      _titleController.clear();
      _contentController.clear();
      selectedDate = null;
      selectedTime = null;
      postNow = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Post", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008B8B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input("Title", _titleController),
            _input("Content", _contentController, maxLines: 5),

            SwitchListTile(
              title: const Text("Post Now"),
              activeColor: const Color(0xFF008B8B),
              value: postNow,
              onChanged: (v) => setState(() => postNow = v),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : createOrUpdatePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008B8B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  editingPostId == null ? "Publish Post" : "Update Post",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            const Text(
              "Previous Posts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...posts.map(
              (post) => Card(
                child: ListTile(
                  title: Text(post['title']),
                  subtitle: Text(
                    post['content'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => _editPost(post),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePost(post['id']),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
