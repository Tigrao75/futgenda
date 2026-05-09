import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/group_service.dart';
import '../../services/event_service.dart';
import '../../models/event_model.dart';
import '../../models/event_participant_model.dart';


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

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          if (email.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Digite um email')),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            await _groupService.addMemberByEmail(
                              groupId: widget.groupId,
                              email: email,
                            );

                            if (!mounted) return;

                            navigator.pop();

                            messenger.showSnackBar(
                              const SnackBar(content: Text('Membro adicionado')),
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

                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(content: Text(message)));
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
    final messenger = ScaffoldMessenger.of(context);
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
          if (!mounted) return;
          messenger.showSnackBar(
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
          if (!mounted) return;
          messenger.showSnackBar(
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
          if (!mounted) return;
          messenger.showSnackBar(
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
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Membro removido de Capitão')),
          );
          break;
      }
    } catch (e) {
      debugPrint('action blocked: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deletar Grupo'),
          content: const Text('Tem certeza que deseja deletar este grupo? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _groupService.deleteGroup(widget.groupId);
                  if (!mounted) return;
                  navigator.pop(); // Fechar dialog
                  Navigator.of(context).pop(); // Voltar para lista de grupos
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Grupo deletado')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes do Grupo'),
          actions: [
            if (_canInviteMembers == true)
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: _showAddMemberDialog,
              ),
            if (_canDeleteGroup == true)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _showDeleteGroupDialog,
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gramado'),
              Tab(text: 'Vestiário'),
              Tab(text: 'CT'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GramadoTab(
              groupId: widget.groupId,
              groupService: _groupService,
              currentUserRole: _currentUserRole,
            ),
            _VestiarioTab(
              groupId: widget.groupId,
              groupService: _groupService,
              canChangeMemberType: _canChangeMemberType,
              canPromoteAdmin: _canPromoteAdmin,
              currentUserRole: _currentUserRole,
              onMemberAction: _handleMemberAction,
            ),
            const _CTTab(),
            _HistoricoTab(groupId: widget.groupId),
          ],
        ),
      ),
    );
  }
}

class _GramadoTab extends StatefulWidget {
  final String groupId;
  final GroupService groupService;
  final String? currentUserRole;

  const _GramadoTab({
    required this.groupId,
    required this.groupService,
    required this.currentUserRole,
  });

  @override
  State<_GramadoTab> createState() => _GramadoTabState();
}

class _GramadoTabState extends State<_GramadoTab> {
  final EventService _eventService = EventService();
  bool _isOpening = false;

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

  String getStatusLabel(String status) {
    switch (status) {
      case 'confirmado':
        return 'Confirmado';
      case 'arregou':
        return 'Arregou';
      case 'lista_espera':
        return 'Lista de espera';
      default:
        return 'Aguardando';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'confirmado':
        return Colors.green;
      case 'arregou':
        return Colors.red;
      case 'lista_espera':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool get _canOpenPelada {
    return widget.currentUserRole == 'owner' || widget.currentUserRole == 'admin';
  }

  bool get _canManagePelada {
    return widget.currentUserRole == 'owner' || widget.currentUserRole == 'admin';
  }

  bool _canEditParticipant(String participantUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isManager = widget.currentUserRole == 'owner' || widget.currentUserRole == 'admin';
    return isManager || currentUserId == participantUserId;
  }

  Future<void> _openPelada() async {
    setState(() => _isOpening = true);
    try {
      await _eventService.openPelada(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pelada aberta com sucesso'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao abrir pelada: $e');
      if (!mounted) return;
      
      // Melhorar mensagem de erro exibida
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  Future<void> _updatePresence({
    required String eventId,
    required String userId,
    required String newStatus,
  }) async {
    try {
      await _eventService.updatePresence(
        groupId: widget.groupId,
        eventId: eventId,
        userId: userId,
        newStatus: newStatus,
      );
      if (!mounted) return;
      final message = newStatus == 'arregou' ? 'Presença atualizada' : 'Status atualizado para ${getStatusLabel(newStatus)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('Erro ao atualizar presença: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }

  Widget _buildParticipantsSection(String title, List<EventParticipant> participants, String eventId) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$title (${participants.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...participants.map((participant) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(participant.userId).get(),
            builder: (context, userSnapshot) {
              final nickname = userSnapshot.data?.data() is Map<String, dynamic>
                  ? (userSnapshot.data!.data() as Map<String, dynamic>)['nickname'] ?? 'Sem apelido'
                  : 'Carregando...';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(nickname),
                  subtitle: Text(
                    '${getRoleLabel(participant.role)} • ${getTypeLabel(participant.type)}',
                  ),
                  trailing: SizedBox(
                    width: 140,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          getStatusLabel(participant.status),
                          style: TextStyle(
                            color: getStatusColor(participant.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_canEditParticipant(participant.userId))
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              SizedBox(
                                height: 32,
                                child: TextButton(
                                  onPressed: () => _updatePresence(
                                    eventId: eventId,
                                    userId: participant.userId,
                                    newStatus: 'confirmado',
                                  ),
                                  child: const Text('Confirmar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                              SizedBox(
                                height: 32,
                                child: TextButton(
                                  onPressed: () => _updatePresence(
                                    eventId: eventId,
                                    userId: participant.userId,
                                    newStatus: 'arregou',
                                  ),
                                  child: const Text('Arregar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showCancelDialog(String eventId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar Pelada'),
          content: const Text('Tem certeza que quer cancelar a pelada?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('NÃO'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _eventService.cancelPelada(
                    groupId: widget.groupId,
                    eventId: eventId,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Pelada cancelada')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Erro ao cancelar pelada: $e');
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Erro ao cancelar pelada')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('SIM'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseDialog(String eventId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Fechar Pelada'),
          content: const Text('Tem certeza que quer fechar a pelada?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('NÃO'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _eventService.closePelada(
                    groupId: widget.groupId,
                    eventId: eventId,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Pelada fechada')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Erro ao fechar pelada: $e');
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Erro ao fechar pelada')),
                  );
                }
              },
              child: const Text('SIM'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Event?>(
      stream: _eventService.getOpenEvent(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('═══ Gramado Error ═══');
          debugPrint('groupId: ${widget.groupId}');
          debugPrint('Error type: ${snapshot.error.runtimeType}');
          debugPrint('Error: ${snapshot.error}');
          debugPrint('════════════════════');
          return const Center(child: Text('Erro ao carregar pelada'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final openEvent = snapshot.data;
        if (openEvent == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Nenhuma pelada aberta',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Nenhum evento está aberto para confirmação.'),
                const SizedBox(height: 24),
                if (_canOpenPelada)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isOpening ? null : _openPelada,
                      child: _isOpening
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Abrir Pelada'),
                    ),
                  ),
              ],
            ),
          );
        }

        return StreamBuilder<List<EventParticipant>>(
          stream: _eventService.getParticipants(widget.groupId, openEvent.id),
          builder: (context, participantsSnapshot) {
            if (participantsSnapshot.hasError) {
              debugPrint('═══ Participants Error ═══');
              debugPrint('groupId: ${widget.groupId}, eventId: ${openEvent.id}');
              debugPrint('Error type: ${participantsSnapshot.error.runtimeType}');
              debugPrint('Error: ${participantsSnapshot.error}');
              debugPrint('═════════════════════════');
              return const Center(child: Text('Erro ao carregar participantes'));
            }

            if (participantsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final participants = participantsSnapshot.data ?? <EventParticipant>[];

            // Buscar group para maxParticipants
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get(),
              builder: (context, groupSnapshot) {
                if (!groupSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
                final maxParticipants = groupData['maxParticipants'] ?? 0;

                // Separar participantes por status
                final confirmados = participants.where((p) => p.status == 'confirmado').toList();
                final listaEspera = participants.where((p) => p.status == 'lista_espera').toList();
                final aguardando = participants.where((p) => p.status == 'aguardando').toList();
                final arregaram = participants.where((p) => p.status == 'arregou').toList();

                // Ordenar cada seção
                confirmados.sort((a, b) => (a.confirmedAt ?? DateTime.now()).compareTo(b.confirmedAt ?? DateTime.now()));
                listaEspera.sort((a, b) => (a.confirmedAt ?? DateTime.now()).compareTo(b.confirmedAt ?? DateTime.now()));
                aguardando.sort((a, b) => a.userId.compareTo(b.userId));
                arregaram.sort((a, b) => a.userId.compareTo(b.userId));

                return Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pelada de ${_formatDate(openEvent.date)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Horário: ${openEvent.startTime} - ${openEvent.endTime}'),
                              const SizedBox(height: 8),
                              Text('Status: ${openEvent.status == 'open' ? 'Aberta' : 'Fechada'}'),
                              const SizedBox(height: 8),
                              if (_canOpenPelada)
                                const Text('Você pode alterar o status de qualquer participante.'),
                              const SizedBox(height: 16),
                              // Resumo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text('Confirmados: ${confirmados.length} / $maxParticipants'),
                                  Text('Lista: ${listaEspera.length}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text('Aguardando: ${aguardando.length}'),
                                  Text('Arregaram: ${arregaram.length}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_canManagePelada)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showCloseDialog(openEvent.id),
                                child: const Text('Fechar Pelada'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showCancelDialog(openEvent.id),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Cancelar Pelada'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _buildParticipantsSection('Confirmados', confirmados, openEvent.id),
                      _buildParticipantsSection('Lista de Espera', listaEspera, openEvent.id),
                      _buildParticipantsSection('Aguardando Resposta', aguardando, openEvent.id),
                      _buildParticipantsSection('Arregaram', arregaram, openEvent.id),
                    ],
                  ),
                );
              },
            );

          },
        );
      },
    );
  }
}

class _HistoricoTab extends StatelessWidget {
  final String groupId;

  const _HistoricoTab({required this.groupId});

  String _translateStatus(String status) {
    switch (status) {
      case 'closed':
        return 'Fechada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Desconhecido';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Presidente';
      case 'admin':
        return 'Capitão';
      default:
        return '';
    }
  }

  String _getTypeLabel(String type) {
    return type == 'mensalista' ? 'Mensalista' : 'Avulso';
  }

  Widget _buildParticipantRow(EventParticipant participant) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(participant.userId).get(),
      builder: (context, userSnapshot) {
        final userName = userSnapshot.hasData && userSnapshot.data!.exists
            ? ((userSnapshot.data!.data() as Map<String, dynamic>?)?['nickname'] ?? 'Sem apelido')
            : 'Sem apelido';

        return ListTile(
          title: Text(userName),
          subtitle: Text('${_getRoleLabel(participant.role)} • ${_getTypeLabel(participant.type)}'),
          trailing: Text(
            participant.status == 'confirmado'
                ? 'Confirmado'
                : participant.status == 'lista_espera'
                    ? 'Lista de espera'
                    : participant.status == 'arregou'
                        ? 'Arregou'
                        : 'Aguardando',
            style: TextStyle(
              color: participant.status == 'confirmado'
                  ? Colors.green
                  : participant.status == 'arregou'
                      ? Colors.red
                      : participant.status == 'lista_espera'
                          ? Colors.orange
                          : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<EventParticipant> participants) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            '$title (${participants.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...participants.map(_buildParticipantRow),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();
    return StreamBuilder<List<Event>>(
      stream: eventService.getEventHistory(groupId),
      builder: (context, historySnapshot) {
        if (historySnapshot.hasError) {
          debugPrint('═══ Histórico Error ═══');
          debugPrint('groupId: $groupId');
          debugPrint('Error type: ${historySnapshot.error.runtimeType}');
          debugPrint('Error: ${historySnapshot.error}');
          debugPrint('════════════════════');
          return const Center(child: Text('Erro ao carregar histórico'));
        }

        if (historySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = historySnapshot.data ?? <Event>[];
        if (events.isEmpty) {
          return const Center(child: Text('Nenhuma pelada no histórico'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text('${_formatDate(event.date)} • ${event.startTime} - ${event.endTime}'),
                subtitle: Text(_translateStatus(event.status)),
                children: [
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .collection('events')
                        .doc(event.id)
                        .collection('participants')
                        .get(),
                    builder: (context, participantsSnapshot) {
                      if (participantsSnapshot.hasError) {
                        debugPrint('Erro ao carregar participantes do histórico: ${participantsSnapshot.error}');
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Erro ao carregar participantes'),
                        );
                      }

                      if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final participantDocs = participantsSnapshot.data?.docs ?? [];
                      final participants = participantDocs
                          .map((doc) => EventParticipant.fromMap(doc.data() as Map<String, dynamic>))
                          .toList();

                      final confirmados = participants.where((p) => p.status == 'confirmado').toList();
                      final listaEspera = participants.where((p) => p.status == 'lista_espera').toList();
                      final aguardando = participants.where((p) => p.status == 'aguardando').toList();
                      final arregaram = participants.where((p) => p.status == 'arregou').toList();

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumo',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text('Confirmados: ${confirmados.length}')),
                                Chip(label: Text('Lista de espera: ${listaEspera.length}')),
                                Chip(label: Text('Arregaram: ${arregaram.length}')),
                                Chip(label: Text('Aguardando: ${aguardando.length}')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSection('Confirmados', confirmados),
                            _buildSection('Lista de espera', listaEspera),
                            _buildSection('Aguardando', aguardando),
                            _buildSection('Arregaram', arregaram),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
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