/// Pronostic reçu d'un ami, stocké sous users/{uid}/received/{id}
class SharedPrediction {
  final String id;
  final String fromUid;
  final String fromName;
  final String matchLabel;
  final String selection; // '1', 'N', '2'
  final double odds;
  final int confidence;
  final String comment;
  final DateTime createdAt;

  /// 'pending' → écrit en Firestore, en attente d'envoi MQTT
  /// 'sent'    → publié sur le topic MQTT de l'appareil
  final String mqttStatus;

  const SharedPrediction({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.matchLabel,
    required this.selection,
    required this.odds,
    required this.confidence,
    required this.comment,
    required this.createdAt,
    this.mqttStatus = 'pending',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'matchLabel': matchLabel,
        'selection': selection,
        'odds': odds,
        'confidence': confidence,
        'comment': comment,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'mqttStatus': mqttStatus,
      };

  factory SharedPrediction.fromJson(Map<String, dynamic> json) =>
      SharedPrediction(
        id: json['id'] as String,
        fromUid: json['fromUid'] as String? ?? '',
        fromName: json['fromName'] as String? ?? 'Inconnu',
        matchLabel: json['matchLabel'] as String,
        selection: json['selection'] as String,
        odds: (json['odds'] as num).toDouble(),
        confidence: json['confidence'] as int? ?? 1,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        mqttStatus: json['mqttStatus'] as String? ?? 'pending',
      );
}
