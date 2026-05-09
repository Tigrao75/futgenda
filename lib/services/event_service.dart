import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../models/group_model.dart';
import 'group_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService _groupService = GroupService();

  Future<void> openPelada(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final currentRole = await _groupService.getCurrentUserRole(groupId);
    if (currentRole != 'owner' && currentRole != 'admin') {
      throw Exception('Sem permissão para abrir pelada');
    }

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw Exception('Grupo não encontrado');
    }

    final group = Group.fromMap(groupDoc.data() as Map<String, dynamic>, id: groupDoc.id);
    final eventDate = _calculateNextDate(group.eventDay);
    final eventDateTimestamp = Timestamp.fromDate(DateTime(eventDate.year, eventDate.month, eventDate.day));

    debugPrint('═══ openPelada: Verificando duplicidade ═══');
    debugPrint('Data da pelada: $eventDate');
    debugPrint('Timestamp: $eventDateTimestamp');

    // Verificar se já existe pelada ABERTA para esta data
    // Eventos cancelados ou fechados NÃO devem bloquear a criação
    final existingEventSnapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .where('date', isEqualTo: eventDateTimestamp)
        .where('status', isEqualTo: 'open')
        .get();

    debugPrint('Eventos abertos encontrados: ${existingEventSnapshot.docs.length}');

    if (existingEventSnapshot.docs.isNotEmpty) {
      debugPrint('Bloqueando: Já existe pelada aberta para esta data');
      throw Exception('Já existe pelada aberta para esta data');
    }

    debugPrint('Permitindo criação: Nenhuma pelada aberta encontrada');

    final memberSnapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();

    if (memberSnapshot.docs.isEmpty) {
      throw Exception('Grupo sem membros');
    }

    final eventRef = _firestore.collection('groups').doc(groupId).collection('events').doc();
    final now = Timestamp.now();
    final event = Event(
      id: eventRef.id,
      groupId: groupId,
      date: eventDate,
      startTime: group.startTime,
      endTime: group.endTime,
      status: 'open',
      createdBy: currentUser.uid,
      createdAt: now.toDate(),
    );

    final batch = _firestore.batch();
    batch.set(eventRef, event.toMap());

    for (final memberDoc in memberSnapshot.docs) {
      final memberData = memberDoc.data();
      final userId = memberData['userId'] ?? memberDoc.id;
      final role = memberData['role'] ?? 'member';
      final type = memberData['type'] ?? 'avulso';

      final participantRef = eventRef.collection('participants').doc(userId);
      batch.set(participantRef, {
        'userId': userId,
        'status': 'aguardando',
        'role': role,
        'type': type,
        'updatedAt': now,
      });
    }

    await batch.commit();
    debugPrint('✓ Pelada criada com sucesso');
    debugPrint('Event ID: ${eventRef.id}');
    debugPrint('Membros adicionados: ${memberSnapshot.docs.length}');
    debugPrint('═════════════════════════════════════════');
  }

  Stream<Event?> getOpenEvent(String groupId) {
    debugPrint('═══ EventService.getOpenEvent ═══');
    debugPrint('groupId: $groupId');
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .where('status', isEqualTo: 'open')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      debugPrint('Snapshot received: ${snapshot.docs.length} docs');
      if (snapshot.docs.isEmpty) {
        debugPrint('No open events found');
        return null;
      }
      try {
        final doc = snapshot.docs.first;
        debugPrint('Event doc: ${doc.id}');
        final event = Event.fromMap(doc.id, doc.data());
        debugPrint('Event parsed: ${event.id}');
        return event;
      } catch (e) {
        debugPrint('Error parsing event: $e');
        rethrow;
      }
    }).handleError((error) {
      debugPrint('Stream error in getOpenEvent: $error');
      debugPrint('═══════════════════════════════════');
      throw error;
    });
  }

  Stream<List<Event>> getEventHistory(String groupId) {
    debugPrint('═══ EventService.getEventHistory ═══');
    debugPrint('groupId: $groupId');
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .where('status', whereIn: ['closed', 'cancelled'])
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => Event.fromMap(doc.id, doc.data()))
          .toList();
      events.sort((a, b) => b.date.compareTo(a.date));
      return events;
    }).handleError((error) {
      debugPrint('Stream error in getEventHistory: $error');
      debugPrint('═════════════════════════════');
      throw error;
    });
  }

  Future<void> closePelada({
    required String groupId,
    required String eventId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final currentRole = await _groupService.getCurrentUserRole(groupId);
    if (currentRole != 'owner' && currentRole != 'admin') {
      throw Exception('Permissão negada: somente Presidente e Capitão podem fechar a pelada');
    }

    debugPrint('Fechando pelada: $eventId');
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId)
        .update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('Pelada fechada com sucesso');
  }

  Future<bool> _hasPendingMensalista({
    required String groupId,
    required String eventId,
  }) async {
    final participantsCollection = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId)
        .collection('participants');

    final pendingMensalistas = await participantsCollection
        .where('type', isEqualTo: 'mensalista')
        .where('status', isEqualTo: 'aguardando')
        .get();

    return pendingMensalistas.docs.isNotEmpty;
  }

  Stream<List<EventParticipant>> getParticipants(String groupId, String eventId) {
    debugPrint('═══ EventService.getParticipants ═══');
    debugPrint('groupId: $groupId, eventId: $eventId');
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      debugPrint('Participants snapshot: ${snapshot.docs.length} participants');
      return snapshot.docs
          .map((doc) => EventParticipant.fromMap(doc.data()))
          .toList();
    }).handleError((error) {
      debugPrint('Stream error in getParticipants: $error');
      debugPrint('═════════════════════════════════════');
      throw error;
    });
  }

  Future<void> updatePresence({
    required String groupId,
    required String eventId,
    required String userId,
    required String newStatus,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final currentRole = await _groupService.getCurrentUserRole(groupId);
    if (currentRole != 'owner' && currentRole != 'admin' && currentUser.uid != userId) {
      throw Exception('Permissão negada: somente o usuário pode alterar seu próprio status');
    }

    if (newStatus != 'confirmado' &&
        newStatus != 'arregou' &&
        newStatus != 'aguardando' &&
        newStatus != 'lista_espera') {
      throw Exception('Status inválido');
    }

    final eventRef = _firestore.collection('groups').doc(groupId).collection('events').doc(eventId);
    final participantRef = eventRef.collection('participants').doc(userId);
    final participantDoc = await participantRef.get();

    if (!participantDoc.exists) {
      throw Exception('Participante não encontrado');
    }

    final currentParticipant = EventParticipant.fromMap(participantDoc.data() as Map<String, dynamic>);
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final group = Group.fromMap(groupDoc.data() as Map<String, dynamic>, id: groupDoc.id);
    final participantsCollection = eventRef.collection('participants');
    final now = Timestamp.now();

    if (newStatus == 'confirmado') {
      if (currentParticipant.status == 'confirmado') {
        await participantRef.update({'updatedAt': now});
        debugPrint('updatePresence: userId=$userId, type=${currentParticipant.type}, oldStatus=${currentParticipant.status}, requestedStatus=$newStatus, finalStatus=${currentParticipant.status}, confirmados=N/A');
        return;
      }

      String statusToSave;
      if (currentParticipant.type == 'mensalista') {
        // Mensalistas: contar confirmados
        final confirmedSnapshot = await participantsCollection.where('status', isEqualTo: 'confirmado').get();
        final confirmedCount = confirmedSnapshot.docs.length;
        statusToSave = confirmedCount >= group.maxParticipants ? 'lista_espera' : 'confirmado';
        debugPrint('updatePresence: userId=$userId, type=${currentParticipant.type}, oldStatus=${currentParticipant.status}, requestedStatus=$newStatus, finalStatus=$statusToSave, confirmados=$confirmedCount, maxParticipants=${group.maxParticipants}, hasPendingMensalista=N/A');

        await participantRef.update({
          'status': statusToSave,
          'updatedAt': now,
          'confirmedAt': now, // Sempre setar confirmedAt para preservar ordem
        });

        if (statusToSave == 'lista_espera') {
          debugPrint('Usuário $userId entrou na lista de espera para evento $eventId');
        }

        return;
      } else {
        // Avulsos: verificar se há mensalistas aguardando
        final hasPendingMensalista = await _hasPendingMensalista(groupId: groupId, eventId: eventId);
        final confirmedSnapshot = await participantsCollection.where('status', isEqualTo: 'confirmado').get();
        final confirmedCount = confirmedSnapshot.docs.length;

        if (hasPendingMensalista) {
          statusToSave = 'lista_espera';
        } else {
          statusToSave = confirmedCount >= group.maxParticipants ? 'lista_espera' : 'confirmado';
        }

        final confirmedAtToSave = currentParticipant.confirmedAt != null ? Timestamp.fromDate(currentParticipant.confirmedAt!) : now;
        debugPrint('updatePresence: userId=$userId, type=${currentParticipant.type}, oldStatus=${currentParticipant.status}, requestedStatus=$newStatus, hasPendingMensalista=$hasPendingMensalista, confirmedCount=$confirmedCount, maxParticipants=${group.maxParticipants}, finalStatus=$statusToSave');

        await participantRef.update({
          'status': statusToSave,
          'updatedAt': now,
          'confirmedAt': confirmedAtToSave,
        });

        if (statusToSave == 'lista_espera') {
          debugPrint('Usuário $userId entrou na lista de espera para evento $eventId');
        }

        return;
      }
    }

    if (newStatus == 'arregou') {
      final wasConfirmed = currentParticipant.status == 'confirmado';

      debugPrint('updatePresence: userId=$userId, type=${currentParticipant.type}, oldStatus=${currentParticipant.status}, requestedStatus=$newStatus, finalStatus=arregou, confirmados=N/A');

      if (wasConfirmed) {
        // Contar confirmados atuais e subtrair o participante que vai sair
        final confirmedSnapshot = await participantsCollection.where('status', isEqualTo: 'confirmado').get();
        final confirmedCountAfterLeaving = confirmedSnapshot.docs.isNotEmpty ? confirmedSnapshot.docs.length - 1 : 0;

        // Usar batch para atualizar quem arregou e promover o próximo de forma consistente
        final batch = _firestore.batch();

        // Atualizar o participante atual para arregou
        batch.update(participantRef, {
          'status': 'arregou',
          'updatedAt': now,
          'confirmedAt': null,
        });

        // Promover o próximo da lista de espera
        await _promoteNextFromWaitingListInBatch(
          batch: batch,
          groupId: groupId,
          eventId: eventId,
          participantsCollection: participantsCollection,
          group: group,
          now: now,
          confirmedCountAfterLeaving: confirmedCountAfterLeaving,
        );

        await batch.commit();

        debugPrint('Batch committed for arregou and promotion in event $eventId');
      } else {
        // Se não estava confirmado, apenas atualizar para arregou
        await participantRef.update({
          'status': 'arregou',
          'updatedAt': now,
          'confirmedAt': null,
        });
      }

      return;
    }

    await participantRef.update({
      'status': newStatus,
      'updatedAt': now,
      'confirmedAt': null,
    });
  }

  Future<void> _promoteNextFromWaitingListInBatch({
    required WriteBatch batch,
    required String groupId,
    required String eventId,
    required CollectionReference participantsCollection,
    required Group group,
    required Timestamp now,
    required int confirmedCountAfterLeaving,
  }) async {
    // Contar confirmados após o participante que arrgou sair
    final confirmedCount = confirmedCountAfterLeaving;

    debugPrint('_promoteNextFromWaitingList: evento $eventId, confirmados após saída=$confirmedCount, max=${group.maxParticipants}');

    if (confirmedCount >= group.maxParticipants) {
      debugPrint('Não há vagas disponíveis para promoção no evento $eventId');
      return;
    }

    // Verificar se há mensalistas aguardando; se sim, não promover avulsos
    final hasPendingMensalista = await _hasPendingMensalista(groupId: groupId, eventId: eventId);
    if (hasPendingMensalista) {
      debugPrint('Há mensalistas aguardando; não promover avulsos no evento $eventId');
      return;
    }

    // Buscar lista de espera ordenada por confirmedAt ASC (avulsos têm prioridade se não houver mensalistas aguardando)
    final waitingListSnapshot = await participantsCollection
        .where('status', isEqualTo: 'lista_espera')
        .orderBy('confirmedAt')
        .limit(1)
        .get();

    debugPrint('Waiting list query result: ${waitingListSnapshot.docs.length} docs');

    if (waitingListSnapshot.docs.isEmpty) {
      debugPrint('Não há avulsos na lista de espera para o evento $eventId');
      return;
    }

    final nextInLine = waitingListSnapshot.docs.first;
    final nextUserId = nextInLine.id;
    final nextData = nextInLine.data() as Map<String, dynamic>?;
    final nextType = nextData?['type'] ?? 'avulso';
    final oldStatus = nextData?['status'] ?? 'lista_espera';

    debugPrint('Promovendo avulso: userId=$nextUserId, path=${nextInLine.reference.path}, oldStatus=$oldStatus');

    // Promover o próximo da fila para confirmado
    // Manter confirmedAt original para preservar a ordem de tentativa
    batch.update(nextInLine.reference, {
      'status': 'confirmado',
      'updatedAt': now,
      // 'confirmedAt' permanece o mesmo
    });

    debugPrint('Avulso promovido: userId=$nextUserId, type=$nextType, oldStatus=$oldStatus, newStatus=confirmado, evento $eventId');
  }

  Future<void> cancelPelada({
    required String groupId,
    required String eventId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final currentRole = await _groupService.getCurrentUserRole(groupId);
    if (currentRole != 'owner' && currentRole != 'admin') {
      throw Exception('Permissão negada: somente Presidente e Capitão podem cancelar pelada');
    }

    debugPrint('Cancelando pelada: $eventId');
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId)
        .update({'status': 'cancelled'});
    debugPrint('Pelada cancelada com sucesso');
  }

  DateTime _calculateNextDate(String eventDay) {
    final now = DateTime.now();
    final weekdayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final desiredWeekday = weekdayMap[eventDay] ?? DateTime.sunday;
    var daysAhead = (desiredWeekday - now.weekday) % DateTime.daysPerWeek;
    if (daysAhead <= 0) {
      daysAhead += DateTime.daysPerWeek;
    }

    final nextDate = now.add(Duration(days: daysAhead));
    return DateTime(nextDate.year, nextDate.month, nextDate.day);
  }
}
