import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../groups/group_list_page.dart';
import 'login_page.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return const GroupListPage();
    } else {
      return const LoginPage();
    }
  }
}