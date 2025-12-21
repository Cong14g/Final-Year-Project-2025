import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiScanService {
  static const String _apiUrl =
      'https://nuryzhamzah-eatwise-api.hf.space/predict';

  static Future<Map<String, dynamic>> callEatWiseAPI(File imageFile) async {
    try {
      final uri = Uri.parse(_apiUrl);

      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('AI server timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Prediction failed (status ${response.statusCode})');
      }

      final body = await response.stream.bytesToString();
      final decoded = jsonDecode(body);

      return decoded as Map<String, dynamic>;
    } catch (e) {
      throw Exception('AI scan failed: $e');
    }
  }

  static Future<void> saveScanResult({
    required String foodName,
    required int calories,
    double? protein,
    double? fat,
    double? carbs,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await supabase.from('calorie_logs').insert({
      'user_id': user.id,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    });
  }
}
