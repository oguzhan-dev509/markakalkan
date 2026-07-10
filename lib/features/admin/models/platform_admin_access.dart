class PlatformAdminAccess {
  const PlatformAdminAccess({
    required this.active,
    required this.roles,
    required this.displayName,
    required this.email,
  });

  final bool active;
  final List<String> roles;
  final String displayName;
  final String email;

  bool get isSuperAdmin => active && roles.contains('super_admin');

  factory PlatformAdminAccess.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];

    return PlatformAdminAccess(
      active: map['active'] == true,
      roles: rawRoles is Iterable
          ? rawRoles
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(growable: false)
          : const <String>[],
      displayName: (map['displayName'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim().toLowerCase(),
    );
  }
}
