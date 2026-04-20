import 'package:flutter/material.dart';
import 'features/groups/group_list_page.dart';
import 'features/groups/create_group_page.dart';

void main() {
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
      initialRoute: '/',
      routes: {
        '/': (context) => const GroupListPage(),
        '/create-group': (context) => const CreateGroupPage(),
      },
    );
  }
}