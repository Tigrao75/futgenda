import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createGroup(Group group) async {
  final docRef = await _db.collection('groups').add(group.toMap());

  // cria owner como membro
  await docRef.collection('members').add({
    'userId': group.ownerId,
    'role': 'owner',
    'type': 'mensalista',
  });
}

  Stream<List<Group>> getGroups() {
  return _db.collection('groups').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();

      return Group.fromMap({
        ...data,
        'id': doc.id,
      });

    }).toList();
  });
}
}

