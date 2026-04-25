import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/group_service.dart';


class GroupDetailPage extends StatelessWidget {
  final String groupId;
  final GroupService _groupService = GroupService();

  GroupDetailPage({super.key, required this.groupId});

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

  void _showAddMemberDialog(BuildContext context) {
  final emailController = TextEditingController();
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Adicionar membro'),
            content: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email do usuário',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();

                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Digite um email')),
                          );
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          await _groupService.addMemberByEmail(
                            groupId: groupId,
                            email: email,
                          );

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Membro adicionado')),
                          );
                        } catch (e) {
                          String message = 'Erro ao adicionar';

                          if (e.toString().contains('não encontrado')) {
                            message = 'Usuário não encontrado';
                          } else if (e
                              .toString()
                              .contains('já está no grupo')) {
                            message = 'Usuário já está no grupo';
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        } finally {
                          setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Adicionar'),
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Grupo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddMemberDialog(context),
          ),
      ],
    ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum membro'));
          }

          final members = snapshot.data!.docs;

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final data =
                  members[index].data() as Map<String, dynamic>;

              final role = data['role'] ?? '';
              final type = data['type'] ?? 'avulso';

              return ListTile(
                title: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['userId'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Text('Carregando...');
                    }

                    if (!userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      return const Text('Usuário não encontrado');
                    }

                    final userData = userSnapshot.data!.data()
                        as Map<String, dynamic>?;

                    return Text(
                      userData?['nickname'] ?? 'Sem apelido',
                    );
                  },
                ),
                subtitle: Text(
                  '${getRoleLabel(role)} • ${getTypeLabel(type)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}