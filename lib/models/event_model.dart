import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String groupId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.groupId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Event.fromMap(String id, Map<String, dynamic> map) {
    final dateValue = map['date'];
    final createdAtValue = map['createdAt'];
    DateTime parsedDate;
    DateTime parsedCreatedAt;

    if (dateValue is Timestamp) {
      parsedDate = dateValue.toDate();
    } else if (dateValue is String) {
      parsedDate = DateTime.parse(dateValue);
    } else {
      parsedDate = DateTime.now();
    }

    if (createdAtValue is Timestamp) {
      parsedCreatedAt = createdAtValue.toDate();
    } else if (createdAtValue is String) {
      parsedCreatedAt = DateTime.parse(createdAtValue);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Event(
      id: id,
      groupId: map['groupId'] ?? '',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      startTime: map['startTime'] ?? '--:--',
      endTime: map['endTime'] ?? '--:--',
      status: map['status'] ?? 'open',
      createdBy: map['createdBy'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }
}
