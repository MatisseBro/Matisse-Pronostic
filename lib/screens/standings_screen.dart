import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/football_api_service.dart';
import '../viewmodels/standings_view_model.dart';
import '../models/standing_entry.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLeague = ref.watch(selectedStandingsLeagueProvider);
    final asyncStandings = ref.watch(standingsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Text(
          'Classements',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Sélecteur de championnat ────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: FootballApiService.leagueOrder.length,
              itemBuilder: (context, index) {
                final league = FootballApiService.leagueOrder[index];
                final isSelected = league == selectedLeague;
                return ChoiceChip(
                  label: Text(
                    '${_leagueFlag(league)} ${_leagueShortName(league)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(selectedStandingsLeagueProvider.notifier)
                        .state = league;
                  },
                );
              },
            ),
          ),
          // ── Tableau classement ──────────────────────────────────────
          Expanded(
            child: asyncStandings.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(context, ref, e),
              data: (entries) => _buildTable(context, ref, entries),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    WidgetRef ref,
    List<StandingEntry> entries,
  ) {
    final cs = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(standingsProvider);
          await ref.read(standingsProvider.future);
        },
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined,
                        size: 56, color: cs.outlineVariant),
                    const SizedBox(height: 16),
                    Text('Classement non disponible',
                        style:
                            TextStyle(color: cs.outline, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsProvider);
        await ref.read(standingsProvider.future);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ListView(
              children: [
                // En-tête colonnes
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      _colHeader('#', width: 28, align: TextAlign.center),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Équipe',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4))),
                      _colHeader('J', width: 28, align: TextAlign.center),
                      _colHeader('G', width: 28, align: TextAlign.center),
                      _colHeader('N', width: 28, align: TextAlign.center),
                      _colHeader('P', width: 28, align: TextAlign.center),
                      _colHeader('Pts', width: 36, align: TextAlign.center),
                    ],
                  ),
                ),
                ...entries.asMap().entries.map((e) =>
                    _StandingRow(entry: e.value, isLast: e.key == entries.length - 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final cs = Theme.of(context).colorScheme;
    final isNoInternet = error is NoInternetException;

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
              child: Icon(
                isNoInternet
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 40,
                color: cs.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNoInternet
                  ? 'Pas de connexion'
                  : 'Impossible de charger le classement',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => ref.invalidate(standingsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
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

  static String _leagueShortName(String league) => switch (league) {
        'Premier League' => 'Premier L.',
        _ => league,
      };

  static Widget _colHeader(String text,
      {required double width, TextAlign align = TextAlign.start}) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: align,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final StandingEntry entry;
  final bool isLast;
  const _StandingRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Zones : Champion | UCL | UEL | Relégation (approximation)
    final Color zoneColor;
    if (entry.position == 1) {
      zoneColor = Colors.amber.shade600;
    } else if (entry.position <= 3) {
      zoneColor = cs.primary;
    } else if (entry.position <= 5) {
      zoneColor = Colors.blue.shade400;
    } else if (entry.position >= 18) {
      zoneColor = cs.error;
    } else {
      zoneColor = Colors.transparent;
    }

    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          child: Row(
            children: [
              // Barre de zone colorée
              Container(
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  color: zoneColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 20,
                child: Text(
                  '${entry.position}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: zoneColor == Colors.transparent
                        ? cs.onSurface
                        : zoneColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TeamLogo(url: entry.logoUrl, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.teamName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _cell('${entry.played}'),
              _cell('${entry.won}'),
              _cell('${entry.drawn}'),
              _cell('${entry.lost}'),
              SizedBox(
                width: 36,
                child: Text(
                  '${entry.points}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: zoneColor == Colors.transparent
                        ? cs.onSurface
                        : zoneColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
      ],
    );
  }

  static Widget _cell(String text) {
    return SizedBox(
      width: 28,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String? url;
  final double size;
  const _TeamLogo({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.shield_outlined, size: size * 0.8,
            color: Theme.of(context).colorScheme.outlineVariant),
      );
    }
    return Image.network(
      url!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.shield_outlined, size: size * 0.8,
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
