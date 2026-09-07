class Prediction {
  final String id;
  final String matchLabel;
  final String selection; // '1', 'N' ou '2'
  final double odds;
  final double? stake;
  final String comment;
  final int confidence; // 1 à 5
  final DateTime createdAt;
  final String? result; // null = en attente, 'won', 'lost'
  final int? fixtureId; // ID du match API pour auto-vérification
  final DateTime? kickoffUtc; // coup d'envoi UTC pour blocage à -5 min

  const Prediction({
    required this.id,
    required this.matchLabel,
    required this.selection,
    required this.odds,
    this.stake,
    required this.comment,
    required this.confidence,
    required this.createdAt,
    this.result,
    this.fixtureId,
    this.kickoffUtc,
  });

  double? get potentialGain => stake == null ? null : stake! * odds;

  double? get netProfit => switch (result) {
        'won' => stake == null ? null : stake! * (odds - 1),
        'lost' => stake == null ? null : -stake!,
        _ => null,
      };

  // True si le match est passé (peut être vérifié automatiquement)
  bool get isPast =>
      kickoffUtc != null &&
      DateTime.now().toUtc().difference(kickoffUtc!).inMinutes >= 90;

  Prediction copyWith({
    String? result,
    bool clearResult = false,
    int? fixtureId,
    DateTime? kickoffUtc,
  }) =>
      Prediction(
        id: id,
        matchLabel: matchLabel,
        selection: selection,
        odds: odds,
        stake: stake,
        comment: comment,
        confidence: confidence,
        createdAt: createdAt,
        result: clearResult ? null : (result ?? this.result),
        fixtureId: fixtureId ?? this.fixtureId,
        kickoffUtc: kickoffUtc ?? this.kickoffUtc,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchLabel': matchLabel,
        'selection': selection,
        'odds': odds,
        'stake': stake,
        'comment': comment,
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
        'result': result,
        'fixtureId': fixtureId,
        'kickoffUtc': kickoffUtc?.toIso8601String(),
      };

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        id: json['id'] as String,
        matchLabel: json['matchLabel'] as String,
        selection: json['selection'] as String,
        odds: (json['odds'] as num).toDouble(),
        stake: (json['stake'] as num?)?.toDouble(),
        comment: json['comment'] as String,
        confidence: json['confidence'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        result: json['result'] as String?,
        fixtureId: json['fixtureId'] as int?,
        kickoffUtc: json['kickoffUtc'] != null
            ? DateTime.parse(json['kickoffUtc'] as String)
            : null,
      );
}
