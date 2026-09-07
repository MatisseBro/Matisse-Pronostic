class StandingEntry {
  final int position;
  final String teamName;
  final int points;
  final int played;
  final int won;
  final int drawn;
  final int lost;

  const StandingEntry({
    required this.position,
    required this.teamName,
    required this.points,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
  });

  factory StandingEntry.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>?;
    final teamName = team?['name'] as String?
        ?? json['team_name'] as String?
        ?? '?';

    final stats = json['stats'] as Map<String, dynamic>?
        ?? json['all'] as Map<String, dynamic>?;

    int intFor(List<String> keys) {
      for (final k in keys) {
        final v = (stats ?? json)[k];
        if (v is int) return v;
      }
      return 0;
    }

    return StandingEntry(
      position: json['position'] as int? ?? json['rank'] as int? ?? 0,
      teamName: teamName,
      points:   json['points'] as int? ?? json['pts'] as int? ?? 0,
      played:   intFor(['played', 'games_played']),
      won:      intFor(['win', 'won', 'wins']),
      drawn:    intFor(['draw', 'drawn', 'draws']),
      lost:     intFor(['lose', 'lost', 'losses']),
    );
  }
}
