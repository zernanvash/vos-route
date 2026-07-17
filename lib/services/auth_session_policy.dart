class AuthSessionPolicy {
  AuthSessionPolicy._();

  static const duration = Duration(days: 15);

  static bool isExpired({required DateTime startedAt, required DateTime now}) {
    return !now.toUtc().isBefore(startedAt.toUtc().add(duration));
  }
}
