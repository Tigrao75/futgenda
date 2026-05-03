import 'package:cloud_firestore/cloud_firestore.dart';

class EventParticipant {
  final String userId;
  final String status;
  final String role;
  final String type;
  final DateTime updatedAt;
  final DateTime? confirmedAt;

  EventParticipant({
    required this.userId,
    required this.status,
    required this.role,
    required this.type,
    required this.updatedAt,
    this.confirmedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'role': role,
      'type': type,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
    };
  }

  factory EventParticipant.fromMap(Map<String, dynamic> map) {
    final updatedAtValue = map['updatedAt'];
    final confirmedAtValue = map['confirmedAt'];
    DateTime parsedUpdatedAt;
    DateTime? parsedConfirmedAt;

    if (updatedAtValue is Timestamp) {
      parsedUpdatedAt = updatedAtValue.toDate();
    } else if (updatedAtValue is String) {
      parsedUpdatedAt = DateTime.parse(updatedAtValue);
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    if (confirmedAtValue is Timestamp) {
      parsedConfirmedAt = confirmedAtValue.toDate();
    } else if (confirmedAtValue is String) {
      parsedConfirmedAt = DateTime.parse(confirmedAtValue);
    }

    return EventParticipant(
      userId: map['userId'] ?? '',
      status: map['status'] ?? 'aguardando',
      role: map['role'] ?? 'member',
      type: map['type'] ?? 'avulso',
      updatedAt: parsedUpdatedAt,
      confirmedAt: parsedConfirmedAt,
    );
  }
}
