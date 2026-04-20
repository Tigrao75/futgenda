class Group {
  final String id;
  final String name;
  final String ownerId;
  final int maxParticipants;
  final String eventDay;
  final String startTime;
  final String endTime;

  Group({
  required this.id,
  required this.name,
  required this.ownerId,
  required this.maxParticipants,
  required this.eventDay,
  required this.startTime,
  required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'maxParticipants': maxParticipants,
      'eventDay': eventDay,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      ownerId: map['ownerId'],
      maxParticipants: map['maxParticipants'],
      eventDay: map['eventDay'],
      startTime: map['startTime'],
      endTime: map['endTime'],
    );
  }
}