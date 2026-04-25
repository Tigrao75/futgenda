import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe email e senha')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _authService.login(email, password);

      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer login')),
        );
        return;
      }

      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      String message = 'Erro ao fazer login';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            message = 'Usuário não encontrado';
            break;
          case 'wrong-password':
            message = 'Senha incorreta';
            break;
          case 'invalid-email':
            message = 'Email inválido';
            break;
          case 'user-disabled':
            message = 'Usuário desativado';
            break;
          default:
            message = 'Erro de autenticação';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu email')),
      );
      return;
    }

    try {
  print('TENTANDO RESET PARA: $email');

  await _authService.resetPassword(email);

  print('RESET CHAMADO COM SUCESSO');

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Se o email existir, você receberá instruções. Verifique também o spam.')),
  );
} catch (e) {
  print('ERRO RESET: $e');

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Erro ao enviar email')),
  );
}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : login,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Entrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Criar conta'),
            ),
            TextButton(
              onPressed: resetPassword,
              child: const Text('Esqueci minha senha'),
            ),
          ],
        ),
      ),
    );
  }
}