import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> register() async {
  final name = nameController.text.trim();
  final nickname = nicknameController.text.trim();
  final email = emailController.text.trim();
  final phone = phoneController.text.trim();
  final password = passwordController.text.trim();

  if (name.isEmpty ||
      nickname.isEmpty ||
      email.isEmpty ||
      phone.isEmpty ||
      password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preencha todos os campos')),
    );
    return;
  }

  try {
    final user = await _authService.register(email, password);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao cadastrar')),
      );
      return;
    }

    // 🔥 SALVAR NO FIRESTORE
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'name': name,
      'nickname': nickname,
      'email': email,
      'phone': phone,
    });

    if (!mounted) return;

    Navigator.pop(context);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro no cadastro')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: nicknameController, decoration: const InputDecoration(labelText: 'Apelido')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: const Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}