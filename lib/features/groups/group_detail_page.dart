import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDetailPage extends StatelessWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  String getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Presidente';
      case 'admin':
        return 'Capitão';
      default:
        return '';
    }
  }

  String getTypeLabel(String type) {
    return type == 'mensalista' ? 'Mensalista' : 'Avulso';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Grupo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!.docs;

          if (members.isEmpty) {
            return const Center(child: Text('Nenhum membro'));
          }

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final data = members[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['userId']), // depois vamos trocar por nome
                subtitle: Text(
                  '${getRoleLabel(data['role'])} • ${getTypeLabel(data['type'])}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}