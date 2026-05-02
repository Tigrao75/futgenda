import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/group_service.dart';


class GroupDetailPage extends StatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();

  bool? _canInviteMembers;
  bool? _canChangeMemberType;
  bool? _canPromoteAdmin;
  bool? _canDeleteGroup;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canInvite = await _groupService.canInviteMembers(widget.groupId);
    final canChangeType = await _groupService.canChangeMemberType(widget.groupId);
    final canPromote = await _groupService.canPromoteAdmin(widget.groupId);
    final canDelete = await _groupService.canDeleteGroup(widget.groupId);
    final currentRole = await _groupService.getCurrentUserRole(widget.groupId);

    if (mounted) {
      setState(() {
        _canInviteMembers = canInvite;
        _canChangeMemberType = canChangeType;
        _canPromoteAdmin = canPromote;
        _canDeleteGroup = canDelete;
        _currentUserRole = currentRole;
      });
    }
  }

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
                              groupId: widget.groupId,
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
                            final errorString = e.toString().toLowerCase();

                            if (errorString.contains('não encontrado')) {
                              message = 'Usuário não encontrado';
                            } else if (errorString.contains('já está no grupo')) {
                              message = 'Usuário já está no grupo';
                            } else if (errorString.contains('sem permissão')) {
                              message = 'Sem permissão para convidar membros';
                            } else if (errorString.contains('permission-denied')) {
                              message = 'Sem permissão para buscar usuário';
                            }

                            debugPrint('Erro ao adicionar membro: $e');

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

  void _handleMemberAction(BuildContext context, String userId, String action, String currentRole, String currentType) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('=== Member Action ===');
    debugPrint('currentUserId: $currentUserId');
    debugPrint('currentUserRole: $_currentUserRole');
    debugPrint('targetUserId: $userId');
    debugPrint('targetRole: $currentRole');
    debugPrint('targetType: $currentType');
    debugPrint('action requested: $action');

    try {
      switch (action) {
        case 'change_to_avulso':
          debugPrint('action allowed: change type to avulso');
          await _groupService.updateMemberType(
            groupId: widget.groupId,
            userId: userId,
            type: 'avulso',
          );
          debugPrint('New type: avulso');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membro tornado Avulso')),
          );
          break;
        case 'change_to_mensalista':
          debugPrint('action allowed: change type to mensalista');
          await _groupService.updateMemberType(
            groupId: widget.groupId,
            userId: userId,
            type: 'mensalista',
          );
          debugPrint('New type: mensalista');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membro tornado Mensalista')),
          );
          break;
        case 'promote_to_admin':
          debugPrint('action allowed: promote to admin');
          await _groupService.updateMemberRole(
            groupId: widget.groupId,
            userId: userId,
            role: 'admin',
          );
          debugPrint('New role: admin');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membro promovido para Capitão')),
          );
          break;
        case 'demote_to_member':
          debugPrint('action allowed: demote to member');
          await _groupService.updateMemberRole(
            groupId: widget.groupId,
            userId: userId,
            role: 'member',
          );
          debugPrint('New role: member');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membro removido de Capitão')),
          );
          break;
      }
    } catch (e) {
      debugPrint('action blocked: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }

  void _showDeleteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deletar Grupo'),
          content: const Text('Tem certeza que deseja deletar este grupo? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _groupService.deleteGroup(widget.groupId);
                  if (!context.mounted) return;
                  Navigator.pop(context); // Fechar dialog
                  Navigator.pop(context); // Voltar para lista de grupos
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grupo deletado')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deletar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes do Grupo'),
          actions: [
            if (_canInviteMembers == true)
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () => _showAddMemberDialog(context),
              ),
            if (_canDeleteGroup == true)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteGroupDialog(context),
              ),
          ],
          bottom: const TabBar(
            tabs: [
            Tab(text: 'Gramado'),
            Tab(text: 'Vestiário'),
            Tab(text: 'CT'),
          ],
        ),
      ),
        body: TabBarView(
          children: [
            const _GramadoTab(),
            _VestiarioTab(
              groupId: widget.groupId,
              groupService: _groupService,
              canChangeMemberType: _canChangeMemberType,
              canPromoteAdmin: _canPromoteAdmin,
              currentUserRole: _currentUserRole,
              onMemberAction: _handleMemberAction,
            ),
            const _CTTab(),
          ],
        ),
      ),
    );
  }
}

class _GramadoTab extends StatelessWidget {
  const _GramadoTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Gramado',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Nenhuma pelada aberta'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
              );
            },
            child: const Text('Abrir Pelada'),
          ),
        ],
      ),
    );
  }
}

class _VestiarioTab extends StatelessWidget {
  final String groupId;
  final GroupService groupService;
  final bool? canChangeMemberType;
  final bool? canPromoteAdmin;
  final String? currentUserRole;
  final Function(BuildContext, String, String, String, String) onMemberAction;

  const _VestiarioTab({
    required this.groupId,
    required this.groupService,
    required this.canChangeMemberType,
    required this.canPromoteAdmin,
    required this.currentUserRole,
    required this.onMemberAction,
  });

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
    return StreamBuilder<QuerySnapshot>(
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
            final data = members[index].data() as Map<String, dynamic>;

            final role = data['role'] ?? '';
            final type = data['type'] ?? 'avulso';

            return ListTile(
              title: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['userId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Carregando...');
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const Text('Usuário não encontrado');
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                  return Text(userData?['nickname'] ?? 'Sem apelido');
                },
              ),
              subtitle: Text('${getRoleLabel(role)} • ${getTypeLabel(type)}'),
              trailing: (role == 'owner' && currentUserRole == 'admin')
                  ? null // Admin não pode alterar owner
                  : (canChangeMemberType == true || canPromoteAdmin == true)
                      ? PopupMenuButton<String>(
                          onSelected: (value) => onMemberAction(context, data['userId'], value, role, type),
                          itemBuilder: (context) => [
                            if (canChangeMemberType == true)
                              PopupMenuItem(
                                value: type == 'mensalista' ? 'change_to_avulso' : 'change_to_mensalista',
                                child: Text('Tornar ${type == 'mensalista' ? 'Avulso' : 'Mensalista'}'),
                              ),
                            if (canPromoteAdmin == true)
                              if (role == 'member')
                                const PopupMenuItem(
                                  value: 'promote_to_admin',
                                  child: Text('Promover para Capitão'),
                                )
                              else if (role == 'admin')
                                const PopupMenuItem(
                                  value: 'demote_to_member',
                                  child: Text('Remover Capitão'),
                                ),
                          ],
                        )
                      : null,
            );
          },
        );
      },
    );
  }
}

class _CTTab extends StatelessWidget {
  const _CTTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'CT',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Editar grupo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
            );
          },
        ),
        ListTile(
          title: const Text('Editar evento'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
            );
          },
        ),
      ],
    );
  }
}