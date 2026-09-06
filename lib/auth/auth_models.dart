class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.profileName,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.emailVerified = false,
    this.mfaEnabled = false,
    this.mfaRequired = false,
  });

  final String id;
  final String email;
  final String? profileName;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool mfaRequired;

  String get customerName =>
      _nonBlank(displayName) ?? _nonBlank(profileName) ?? email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileName: json['name'] as String?,
      displayName: json['displayName'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      mfaEnabled: json['mfaEnabled'] as bool? ?? false,
      mfaRequired: json['mfaRequired'] as bool? ?? false,
    );
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? profileName,
    String? displayName,
    String? phone,
    String? avatarUrl,
    bool? emailVerified,
    bool? mfaEnabled,
    bool? mfaRequired,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      profileName: profileName ?? this.profileName,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      mfaRequired: mfaRequired ?? this.mfaRequired,
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class UsernameAvailability {
  const UsernameAvailability({
    required this.username,
    required this.available,
    required this.valid,
    required this.message,
  });

  final String username;
  final bool available;
  final bool valid;
  final String message;

  factory UsernameAvailability.fromJson(Map<String, dynamic> json) {
    return UsernameAvailability(
      username: json['username'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class CustomerRegistrationChallenge {
  const CustomerRegistrationChallenge({
    required this.challengeId,
    required this.step,
    required this.deliveryTarget,
    required this.expiresAt,
  });

  final String challengeId;
  final String step;
  final String deliveryTarget;
  final DateTime? expiresAt;

  factory CustomerRegistrationChallenge.fromJson(Map<String, dynamic> json) {
    final challengeId = json['challengeId'] ?? json['registrationId'];
    final step = json['step'];
    if (challengeId is! String || challengeId.isEmpty || step is! String) {
      throw const FormatException(
        'Registration verification response is incomplete.',
      );
    }

    final expiresAt = json['expiresAt'];
    return CustomerRegistrationChallenge(
      challengeId: challengeId,
      step: step,
      deliveryTarget: json['deliveryTarget'] as String? ?? 'your email address',
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
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

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    AuthUser? user,
    DateTime? sessionExpiresAt,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      sessionExpiresAt: sessionExpiresAt ?? this.sessionExpiresAt,
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
