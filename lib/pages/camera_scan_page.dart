import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scan_result_page.dart';
import 'history_logs_page.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({super.key});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  final supabase = Supabase.instance.client;

  File? _image;
  bool isScanning = false;
  String? familyMemberId;

  final ImagePicker _picker = ImagePicker();

  static const String apiUrl =
      "https://nuryzhamzah-eatwise-api.hf.space/predict";

  @override
  void initState() {
    super.initState();
    _loadFamilyMemberId();
  }

  Future<void> _loadFamilyMemberId() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) return;

    final res = await supabase
        .from('family_members')
        .select('id')
        .eq('email', user.email!)
        .maybeSingle();

    if (res != null && mounted) {
      setState(() => familyMemberId = res['id']);
    }
  }

  Future<void> _openCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _openGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _scanImage() async {
    if (_image == null || familyMemberId == null) return;

    setState(() => isScanning = true);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('image', _image!.path),
      );

      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception("AI server error");
      }

      final body = await response.stream.bytesToString();
      final result = jsonDecode(body);

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ScanResultSheet(
          imageFile: _image!,
          result: result,
          familyMemberId: familyMemberId!,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Scan failed: $e")));
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Scan Food", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008B8B),
        centerTitle: true,

        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryLogsPage()),
              );
            },
            child: const Text(
              "History Logs",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF7AC943),
                          width: 4,
                        ),
                      ),
                      child: _image == null
                          ? const Center(
                              child: Text(
                                "Align food inside frame",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008B8B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Open Camera"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openGallery,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Photos"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (_image != null && !isScanning && familyMemberId != null)
                    ? _scanImage
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AC943),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: isScanning
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Scan Food",
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
