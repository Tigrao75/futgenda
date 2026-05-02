import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lista todos os grupos do usuário atual (owner ou member).
  /// 
  /// IMPORTANTE: Se receber erro sobre índice do Firestore, crie o índice:
  /// 1. No Firebase Console, abra Cloud Firestore
  /// 2. Vá para "Índices"
  /// 3. Crie um índice composite em "members" com:
  ///    - Campo: userId (Ascending)
  ///    - Campo: __name__ (Ascending)
  ///    - Coleção: Todos os documentos em todas as coleções
  Stream<List<Group>> getGroups() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('═══ GroupService.getGroups ═══');
    debugPrint('USER_ID: $userId');

    if (userId == null) {
      debugPrint('❌ USER_ID is null, returning empty stream');
      return const Stream.empty();
    }

    return _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        debugPrint('📊 Query snapshot received');
        debugPrint('MEMBERS_COUNT: ${snapshot.docs.length}');

        final groups = <Group>[];
        final loadedGroupIds = <String>[];
        final errors = <String>[];

        for (var i = 0; i < snapshot.docs.length; i++) {
          final memberDoc = snapshot.docs[i];
          final memberData = memberDoc.data();

          debugPrint('  [Member $i] Data: $memberData');
          debugPrint('  [Member $i] Path: ${memberDoc.reference.path}');

          final groupRef = memberDoc.reference.parent.parent;

          if (groupRef == null) {
            errors.add('Member $i: groupRef is null');
            continue;
          }

          try {
            final groupSnap = await groupRef.get();

            if (!groupSnap.exists) {
              errors.add('Member $i: group ${groupRef.id} does not exist');
              continue;
            }

            final groupData = groupSnap.data();
            debugPrint('  [Member $i] Group data: $groupData');

            if (groupData is! Map<String, dynamic>) {
              errors.add('Member $i: groupData is not Map<String, dynamic>');
              continue;
            }

            final group = Group.fromMap(groupData, id: groupSnap.id);
            groups.add(group);
            loadedGroupIds.add(groupSnap.id);

            debugPrint('  ✅ [Member $i] Group added: ${groupSnap.id}');
          } catch (e) {
            errors.add('Member $i: exception = $e');
            debugPrint('  ❌ [Member $i] Exception: $e');
          }
        }

        debugPrint('📈 GROUPS_LOADED: ${groups.length}');
        debugPrint('GROUP_IDS: $loadedGroupIds');

        if (errors.isNotEmpty) {
          debugPrint('⚠️  ERRORS: $errors');
        }

        debugPrint('═══════════════════════════════════');

        return groups;
      } catch (e) {
        debugPrint('❌ CRITICAL ERROR in getGroups: $e');
        debugPrint('═══════════════════════════════════');
        rethrow;
      }
    }).handleError((error) {
      debugPrint('❌ Stream error in getGroups: $error');
      debugPrint('═══════════════════════════════════');
    });
  }

  Future<void> createGroup(Group group) async {
    await _firestore
        .collection('groups')
        .doc(group.id)
        .set(group.toMap());

    // adiciona o criador como presidente
    await _firestore
        .collection('groups')
        .doc(group.id)
        .collection('members')
        .doc(group.ownerId)
        .set({
      'userId': group.ownerId,
      'role': 'owner',
      'type': 'mensalista',
    });
  }

  Future<void> addMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Usuário não encontrado');
    }

    final userDoc = query.docs.first;
    final userId = userDoc.id;

    final memberRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId);

    final memberSnapshot = await memberRef.get();

    if (memberSnapshot.exists) {
      throw Exception('Usuário já está no grupo');
    }

    await memberRef.set({
      'userId': userId,
      'role': 'member',
      'type': 'avulso',
    });
  }

  Future<void> addMember({
    required String groupId,
    required String userId,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .set({
      'userId': userId,
      'role': 'member',
      'type': 'avulso',
    });
  }

  Future<void> updateMaxParticipants({
    required String groupId,
    required int maxParticipants,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .update({
      'maxParticipants': maxParticipants,
    });
  }

  /// Obtém os dados do membro atual no grupo.
  Future<Map<String, dynamic>?> getCurrentUserMemberData(String groupId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final doc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .get();

    return doc.exists ? doc.data() : null;
  }

  /// Obtém o papel do usuário atual no grupo.
  Future<String?> getCurrentUserRole(String groupId) async {
    final data = await getCurrentUserMemberData(groupId);
    return data?['role'];
  }

  /// Verifica se o usuário atual é owner do grupo.
  Future<bool> isOwner(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'owner';
  }

  /// Verifica se o usuário atual é admin do grupo.
  Future<bool> isAdmin(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'admin';
  }

  /// Verifica se o usuário atual pode convidar membros.
  Future<bool> canInviteMembers(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'owner' || role == 'admin';
  }

  /// Verifica se o usuário atual pode mudar o tipo de membro (mensalista/avulso).
  Future<bool> canChangeMemberType(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'owner' || role == 'admin';
  }

  /// Verifica se o usuário atual pode promover um membro para admin.
  Future<bool> canPromoteAdmin(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'owner' || role == 'admin';
  }

  /// Verifica se o usuário atual pode deletar o grupo.
  Future<bool> canDeleteGroup(String groupId) async {
    final role = await getCurrentUserRole(groupId);
    return role == 'owner';
  }

  /// Atualiza o tipo de um membro (mensalista/avulso).
  Future<void> updateMemberType({
    required String groupId,
    required String userId,
    required String type,
  }) async {
    // Verificar se type é válido
    if (type != 'mensalista' && type != 'avulso') {
      throw Exception('Tipo inválido: deve ser "mensalista" ou "avulso"');
    }

    // Verificar permissão antes de executar
    final canChange = await canChangeMemberType(groupId);
    if (!canChange) {
      throw Exception('Permissão negada: não pode alterar tipo de membro');
    }

    // Verificar se o alvo é owner
    // Na verdade, preciso buscar o data do target
    final targetDoc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .get();
    final targetRole = targetDoc.data()?['role'];

    // Admin não pode alterar o owner
    final currentRole = await getCurrentUserRole(groupId);
    if (currentRole == 'admin' && targetRole == 'owner') {
      throw Exception('Permissão negada: Capitão não pode alterar o Presidente');
    }

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'type': type});
  }

  /// Atualiza o papel de um membro.
  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    // Verificar se role é válido
    if (role != 'admin' && role != 'member') {
      throw Exception('Role inválido: deve ser "admin" ou "member"');
    }

    // Verificar permissão
    final canChange = await canPromoteAdmin(groupId);
    if (!canChange) {
      throw Exception('Permissão negada: não pode alterar papéis');
    }

    // Obter role do alvo
    final targetDoc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .get();
    final targetRole = targetDoc.data()?['role'];

    // Nunca permitir alterar owner
    if (targetRole == 'owner') {
      throw Exception('Permissão negada: não é possível alterar o Presidente');
    }

    // Impedir que o owner mude o próprio role (embora targetRole != 'owner', mas para segurança)
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == currentUserId) {
      throw Exception('Não é possível alterar o próprio papel');
    }

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'role': role});
  }

  /// Deleta o grupo.
  Future<void> deleteGroup(String groupId) async {
    // Verificar permissão antes de executar
    final canDelete = await canDeleteGroup(groupId);
    if (!canDelete) {
      throw Exception('Permissão negada: não pode deletar grupo');
    }

    // TODO: Implementar Firestore Rules para validar permissões no servidor
    await _firestore.collection('groups').doc(groupId).delete();
  }
}