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

  factory Group.fromMap(Map<String, dynamic> map, {String? id}) {
    return Group(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? 'Sem nome',
      ownerId: map['ownerId'] ?? '',
      maxParticipants: map['maxParticipants'] ?? 0,
      eventDay: map['eventDay'] ?? 'Sem data',
      startTime: map['startTime'] ?? '--:--',
      endTime: map['endTime'] ?? '--:--',
    );
  }
}