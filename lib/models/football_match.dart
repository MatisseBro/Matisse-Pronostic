class FootballMatch {
  final int id;
  final String leagueName;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String matchTime;
  final DateTime? kickoffUtc;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final double? homeOdds;
  final double? drawOdds;
  final double? awayOdds;

  const FootballMatch({
    required this.id,
    required this.leagueName,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogoUrl,
    this.awayLogoUrl,
    required this.matchTime,
    this.kickoffUtc,
    this.homeScore,
    this.awayScore,
    required this.status,
    this.homeOdds,
    this.drawOdds,
    this.awayOdds,
  });

  bool get canBet {
    if (status == 'live' || status == 'halftime' ||
        status == 'finished' || status == 'postponed' || status == 'cancelled') {
      return false;
    }
    if (kickoffUtc == null) return true;
    return kickoffUtc!.difference(DateTime.now().toUtc()).inMinutes >= 5;
  }

  Duration? get timeUntilKickoff {
    if (kickoffUtc == null) return null;
    final diff = kickoffUtc!.difference(DateTime.now().toUtc());
    return diff.isNegative ? null : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leagueName': leagueName,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeLogoUrl': homeLogoUrl,
        'awayLogoUrl': awayLogoUrl,
        'matchTime': matchTime,
        'kickoffUtc': kickoffUtc?.toIso8601String(),
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': status,
        'homeOdds': homeOdds,
        'drawOdds': drawOdds,
        'awayOdds': awayOdds,
      };

  factory FootballMatch.fromCacheJson(Map<String, dynamic> json) => FootballMatch(
        id: json['id'] as int,
        leagueName: json['leagueName'] as String,
        homeTeam: json['homeTeam'] as String,
        awayTeam: json['awayTeam'] as String,
        homeLogoUrl: json['homeLogoUrl'] as String?,
        awayLogoUrl: json['awayLogoUrl'] as String?,
        matchTime: json['matchTime'] as String,
        kickoffUtc: json['kickoffUtc'] != null
            ? DateTime.parse(json['kickoffUtc'] as String)
            : null,
        homeScore: json['homeScore'] as int?,
        awayScore: json['awayScore'] as int?,
        status: json['status'] as String,
        homeOdds: (json['homeOdds'] as num?)?.toDouble(),
        drawOdds: (json['drawOdds'] as num?)?.toDouble(),
        awayOdds: (json['awayOdds'] as num?)?.toDouble(),
      );

  factory FootballMatch.fromJson(
    Map<String, dynamic> json, {
    required String leagueName,
    double? homeOdds,
    double? drawOdds,
    double? awayOdds,
  }) {
    final teams = json['teams'] as Map<String, dynamic>;
    final goals = json['goals'] as Map<String, dynamic>?;

    final kickoffUtc = DateTime.parse(json['kickoff_utc'] as String);
    final local = kickoffUtc.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    final status = json['status'] as String? ?? 'scheduled';

    final home = teams['home'] as Map<String, dynamic>;
    final away = teams['away'] as Map<String, dynamic>;

    return FootballMatch(
      id: json['id'] as int,
      leagueName: leagueName,
      homeTeam: home['name'] as String,
      awayTeam: away['name'] as String,
      homeLogoUrl: home['logo'] as String? ?? home['image'] as String?,
      awayLogoUrl: away['logo'] as String? ?? away['image'] as String?,
      matchTime: time,
      kickoffUtc: kickoffUtc,
      homeScore: status == 'scheduled' ? null : goals?['home'] as int?,
      awayScore: status == 'scheduled' ? null : goals?['away'] as int?,
      status: status,
      homeOdds: homeOdds,
      drawOdds: drawOdds,
      awayOdds: awayOdds,
    );
  }
}
