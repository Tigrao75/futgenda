import 'package:flutter/material.dart';

class GroupListPage extends StatelessWidget {
  const GroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Futgenda'),
      ),
      body: const Center(
        child: Text('Nenhum grupo ainda'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-group');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}