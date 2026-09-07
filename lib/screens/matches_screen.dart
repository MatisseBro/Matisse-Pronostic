import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../viewmodels/matches_view_model.dart';
import '../viewmodels/predictions_view_model.dart';
import '../services/auth_service.dart';
import '../services/football_api_service.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final leagueFilter = ref.watch(leagueFilterProvider);
    final asyncMatches = ref.watch(matchesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_soccer, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Matimatch',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: cs.outline),
            tooltip: 'Se déconnecter',
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sélecteur de jour (2 semaines) ──────────────────────────────
          _WeekDayPicker(
            selectedDate: selectedDate,
            onDateSelected: (d) =>
                ref.read(selectedDateProvider.notifier).state = d,
          ),
          // ── Filtre par championnat ────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _LeagueChip(
                  label: 'Tous',
                  selected: leagueFilter == null,
                  onTap: () =>
                      ref.read(leagueFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...FootballApiService.leagueOrder.map((league) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _LeagueChip(
                        label: '${_leagueFlag(league)} $league',
                        selected: leagueFilter == league,
                        onTap: () =>
                            ref.read(leagueFilterProvider.notifier).state =
                                league,
                      ),
                    )),
              ],
            ),
          ),
          // ── Contenu ──────────────────────────────────────────────────
          Expanded(
            child: asyncMatches.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(context, ref, e),
              data: (grouped) =>
                  _buildContent(context, ref, grouped, leagueFilter),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final cs = Theme.of(context).colorScheme;
    final isNoInternet = error is NoInternetException;
    final isRateLimit = error is RateLimitException;

    final icon = isNoInternet
        ? Icons.wifi_off_rounded
        : isRateLimit
            ? Icons.timer_off_rounded
            : Icons.error_outline_rounded;

    final title = isNoInternet
        ? 'Pas de connexion Internet'
        : isRateLimit
            ? 'Quota API dépassé'
            : 'Impossible de charger les matchs';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: cs.onErrorContainer),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => ref.invalidate(matchesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<FootballMatch>> grouped,
    String? leagueFilter,
  ) {
    final filtered = leagueFilter == null
        ? grouped
        : (grouped.containsKey(leagueFilter)
            ? {leagueFilter: grouped[leagueFilter]!}
            : <String, List<FootballMatch>>{});

    final isEmpty =
        filtered.isEmpty || filtered.values.every((l) => l.isEmpty);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesProvider);
        await ref.read(matchesProvider.future);
      },
      child: isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 320,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_soccer_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          leagueFilter == null
                              ? 'Aucun match ce jour-là'
                              : 'Aucun match pour $leagueFilter',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _buildList(context, ref, filtered),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<FootballMatch>> filtered,
  ) {
    final predictedLabels = ref.watch(predictedMatchLabelsProvider);
    final widgets = <Widget>[];

    for (final leagueName in FootballApiService.leagueOrder) {
      final matches = filtered[leagueName];
      if (matches == null || matches.isEmpty) continue;
      widgets.add(_LeagueHeader(name: leagueName));
      for (final match in matches) {
        final label = '${match.homeTeam} - ${match.awayTeam}';
        widgets.add(_MatchCard(
          match: match,
          hasPrediction: predictedLabels.contains(label),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MatchDetailScreen(match: match)),
          ),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: widgets,
    );
  }

  static String _leagueFlag(String league) => switch (league) {
        'Ligue 1' => '🇫🇷',
        'Premier League' => '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
        'Liga' => '🇪🇸',
        'Serie A' => '🇮🇹',
        'Bundesliga' => '🇩🇪',
        _ => '⚽',
      };
}

// ── Sélecteur de jours de la semaine ─────────────────────────────────────────
class _WeekDayPicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDayPicker({
    required this.selectedDate,
    required this.onDateSelected,
  });

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _dayNames = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();

    // Lundi de la semaine courante
    final monday = today.subtract(Duration(days: today.weekday - 1));
    // 14 jours (semaine courante + suivante)
    final days = List.generate(14, (i) => monday.add(Duration(days: i)));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final isSelected = _isSameDay(day, selectedDate);
          final isToday = _isSameDay(day, today);
          final isPast = day.isBefore(DateTime(today.year, today.month, today.day));

          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: cs.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayNames[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? cs.outlineVariant
                              : cs.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? cs.outlineVariant
                              : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Chip de filtre championnat ────────────────────────────────────────────────
class _LeagueChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LeagueChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ── En-tête championnat ───────────────────────────────────────────────────────
class _LeagueHeader extends StatelessWidget {
  final String name;
  const _LeagueHeader({required this.name});

  static const _flags = {
    'Ligue 1': '🇫🇷',
    'Premier League': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
    'Liga': '🇪🇸',
    'Serie A': '🇮🇹',
    'Bundesliga': '🇩🇪',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flag = _flags[name] ?? '⚽';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: cs.outlineVariant, thickness: 1),
          ),
        ],
      ),
    );
  }
}

// ── Carte d'un match ──────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final FootballMatch match;
  final bool hasPrediction;
  final VoidCallback onTap;
  const _MatchCard(
      {required this.match,
      required this.hasPrediction,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant, width: 1),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.homeTeam,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Text(
                                _scoreOrTime(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _StatusBadge(status: match.status),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            match.awayTeam,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildOddsRow(cs),
                  ],
                ),
              ),
              // Badge étoile en coin
              if (hasPrediction)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Parié',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _scoreOrTime() {
    if (match.status != 'scheduled' &&
        match.homeScore != null &&
        match.awayScore != null) {
      return '${match.homeScore} - ${match.awayScore}';
    }
    return match.matchTime;
  }

  Widget _buildOddsRow(ColorScheme cs) {
    if (match.homeOdds == null ||
        match.drawOdds == null ||
        match.awayOdds == null) {
      return Text('Cotes non disponibles',
          style: TextStyle(fontSize: 12, color: cs.outline));
    }
    return Row(
      children: [
        Expanded(
            child: _OddsChip(
                label: '1', value: match.homeOdds!, color: cs.primary)),
        const SizedBox(width: 8),
        Expanded(
            child: _OddsChip(
                label: 'N', value: match.drawOdds!, color: cs.outline)),
        const SizedBox(width: 8),
        Expanded(
            child: _OddsChip(
                label: '2',
                value: match.awayOdds!,
                color: Colors.blue.shade600)),
      ],
    );
  }
}

// ── Badge de statut ───────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'live' => ('⚡ En direct', Colors.green.shade600),
      'halftime' => ('Mi-temps', Colors.orange.shade600),
      'finished' => ('Terminé', Colors.grey.shade500),
      'postponed' => ('Reporté', Colors.red.shade500),
      'cancelled' => ('Annulé', Colors.red.shade500),
      _ => ('À venir', Colors.blue.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Chip de cote ─────────────────────────────────────────────────────────────
class _OddsChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _OddsChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
