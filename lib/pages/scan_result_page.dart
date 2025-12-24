import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanResultSheet extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> result;
  final String familyMemberId;

  const ScanResultSheet({
    super.key,
    required this.imageFile,
    required this.result,
    required this.familyMemberId,
  });

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  final supabase = Supabase.instance.client;

  late TextEditingController _calorieController;
  bool isSaving = false;

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

  Future<void> _confirmAndSave() async {
    final calories = int.tryParse(_calorieController.text.trim());
    if (calories == null || calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid calorie value')),
      );
      return;
    }

    setState(() => isSaving = true);

    final foodName = widget.result['food'] ?? 'Food';

    try {
      await supabase.from('calorie_logs').insert({
        'family_member_id': widget.familyMemberId,
        'food_name': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🍽️ $foodName logged successfully!'),
          backgroundColor: const Color(0xFF7AC943),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save food: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _nutrient(String label, int value) {
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodName = widget.result['food'] ?? 'Unknown';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _nutrient('Protein', protein),
                _nutrient('Carb', carbs),
                _nutrient('Fat', fat),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Calories (kcal)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),

          TextField(
            controller: _calorieController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          const SizedBox(height: 20),

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
                  onPressed: isSaving ? null : _confirmAndSave,
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
    );
  }
}
