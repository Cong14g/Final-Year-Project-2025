import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanResultPage extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> result;

  const ScanResultPage({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  late TextEditingController _calorieController;
  bool isSaving = false;

  final supabase = Supabase.instance.client;

  late int protein;
  late int carbs;
  late int fat;

  @override
  void initState() {
    super.initState();

    final nutrition = widget.result['nutrition'] ?? {};

    _calorieController = TextEditingController(
      text: _toInt(nutrition['calories']).toString(),
    );

    protein = _toInt(nutrition['protein']);
    carbs = _toInt(nutrition['carbs']);
    fat = _toInt(nutrition['fat']);
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    _calorieController.dispose();
    super.dispose();
  }

  Future<void> _saveResult() async {
    final editedCalories = int.tryParse(_calorieController.text.trim());

    if (editedCalories == null || editedCalories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid calorie value')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('calorie_logs').insert({
        'user_id': user.id,
        'food_name': widget.result['food'] ?? 'Unknown',
        'calories': editedCalories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food logged successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _nutritionBox(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodName = widget.result['food'] ?? 'Unknown food';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008B8B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                widget.imageFile,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Food detected',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              foodName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _nutritionBox('Protein', protein),
                  _nutritionBox('Carb', carbs),
                  _nutritionBox('Fat', fat),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Calories (kcal)',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _calorieController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _saveResult,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7AC943),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirm',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
