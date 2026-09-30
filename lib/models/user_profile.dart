class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? deviceId;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.deviceId,
    required this.createdAt,
  });

  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  UserProfile copyWith({String? displayName, String? deviceId, bool clearDevice = false}) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        deviceId: clearDevice ? null : (deviceId ?? this.deviceId),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'deviceId': deviceId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String,
        displayName: json['displayName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        deviceId: json['deviceId'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String).toLocal()
            : DateTime.now(),
      );
}
