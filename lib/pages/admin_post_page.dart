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

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> createPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title and content cannot be empty"),
          backgroundColor: Colors.red,
        ),
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
            const SnackBar(
              content: Text("Please select both date and time"),
              backgroundColor: Colors.red,
            ),
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

      await supabase.from('posts').insert({
        'title': title,
        'content': content,
        'publish_at': publishAt.toIso8601String(),
        'created_by': supabase.auth.currentUser?.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Post published successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to publish post: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
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

  @override
  Widget build(BuildContext context) {
    final dateText = selectedDate == null
        ? "Select date"
        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";

    final timeText = selectedTime == null
        ? "Select time"
        : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Post", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F9D58),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField("Post Title", _titleController),
            _buildInputField("Post Content", _contentController, maxLines: 5),

            const SizedBox(height: 10),
            const Text(
              "Publish Settings",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            SwitchListTile(
              title: const Text("Post Now"),
              activeColor: const Color(0xFF0F9D58),
              value: postNow,
              onChanged: (value) {
                setState(() => postNow = value);
              },
            ),

            if (!postNow) ...[
              const SizedBox(height: 10),
              const Text(
                "Select Publish Date",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: pickDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                ),
                child: Text(
                  dateText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Select Publish Time",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: pickTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                ),
                child: Text(
                  timeText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Publish Post",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
