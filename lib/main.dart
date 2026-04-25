import 'package:flutter/material.dart';
import 'features/groups/group_list_page.dart';
import 'features/groups/create_group_page.dart';
import 'features/auth/register_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/login_page.dart';
import 'features/auth/auth_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Futgenda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),

      // 🔥 NOVO: controla login automático
      home: const AuthCheck(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const GroupListPage(),
        '/create-group': (context) => const CreateGroupPage(),
  },
    );
  }
}