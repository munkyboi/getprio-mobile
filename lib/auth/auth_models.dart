class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.profileName,
    this.displayName,
  });

  final String id;
  final String email;
  final String? profileName;
  final String? displayName;

  String get customerName =>
      _nonBlank(displayName) ?? _nonBlank(profileName) ?? email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileName: json['name'] as String?,
      displayName: json['displayName'] as String?,
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.sessionExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final DateTime sessionExpiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Auth response has no user.');
    }

    final accessToken = json['token'];
    final refreshToken = json['refreshToken'];
    final sessionExpiresAt = json['sessionExpiresAt'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        sessionExpiresAt is! String) {
      throw const FormatException('Auth response has missing session fields.');
    }

    final expiry = DateTime.tryParse(sessionExpiresAt);
    if (expiry == null) {
      throw const FormatException('Auth response has an invalid expiry.');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AuthUser.fromJson(userJson),
      sessionExpiresAt: expiry,
    );
  }
}

sealed class LoginResult {
  const LoginResult();
}

class AuthenticatedSession extends LoginResult {
  const AuthenticatedSession(this.session);

  final AuthSession session;
}

class MfaChallenge extends LoginResult {
  const MfaChallenge({
    required this.challengeToken,
    required this.expiresAt,
    required this.methods,
  });

  final String challengeToken;
  final DateTime expiresAt;
  final List<String> methods;

  factory MfaChallenge.fromJson(Map<String, dynamic> json) {
    final challengeToken = json['challengeToken'];
    final expiresAt = json['expiresAt'];
    final methods = json['methods'];
    final expiry = expiresAt is String ? DateTime.tryParse(expiresAt) : null;
    if (challengeToken is! String || challengeToken.isEmpty || expiry == null) {
      throw const FormatException('MFA response has missing challenge fields.');
    }

    return MfaChallenge(
      challengeToken: challengeToken,
      expiresAt: expiry,
      methods: methods is List
          ? methods.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}
