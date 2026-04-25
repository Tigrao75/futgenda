import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Group>> getGroups() {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return const Stream.empty();
  }

  return _firestore
      .collectionGroup('members')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .asyncMap((snapshot) async {
    final groups = <Group>[];

    for (var doc in snapshot.docs) {
      final groupRef = doc.reference.parent.parent;

      if (groupRef != null) {
        final groupSnap = await groupRef.get();

        if (groupSnap.exists) {
          groups.add(Group.fromMap(groupSnap.data()!));
        }
      }
    }

    return groups;
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