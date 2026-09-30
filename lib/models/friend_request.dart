class FriendRequest {
  final String fromUid;
  final String fromName;
  final String fromEmail;
  final String status;
  final DateTime createdAt;

  const FriendRequest({
    required this.fromUid,
    required this.fromName,
    required this.fromEmail,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'fromUid':   fromUid,
    'fromName':  fromName,
    'fromEmail': fromEmail,
    'status':    status,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    fromUid:   json['fromUid']   as String? ?? '',
    fromName:  json['fromName']  as String? ?? '',
    fromEmail: json['fromEmail'] as String? ?? '',
    status:    json['status']    as String? ?? 'pending',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String).toLocal()
        : DateTime.now(),
  );
}
