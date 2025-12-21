import 'package:eatwiseapp/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoaW5lem9oaG9seWJhend0dGp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0ODE3NzEsImV4cCI6MjA2MzA1Nzc3MX0.YfiAfGgE-0R8-P3n76PIXG0MZz_MwtMGRfickq5D1_M",
    url: "https://fhinezohholybazwttjy.supabase.co",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
