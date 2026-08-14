/// 로그인한 사용자 계정.
class Account {
  const Account({required this.id, required this.username});

  final int id;
  final String username;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}

/// 로그인 결과: 사용자 + 인증 토큰.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final Account user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        user: Account.fromJson(json['user'] as Map<String, dynamic>),
      );
}
