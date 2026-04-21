class AppUser {
  final String id;
  final String name;
  final String nickname;
  final String email;
  final String phone;

  AppUser({
    required this.id,
    required this.name,
    required this.nickname,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nickname': nickname,
      'email': email,
      'phone': phone,
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: map['name'],
      nickname: map['nickname'],
      email: map['email'],
      phone: map['phone'],
    );
  }
}