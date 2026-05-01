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
}