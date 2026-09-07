import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../models/prediction.dart';
import '../viewmodels/predictions_view_model.dart';
import 'add_prediction_screen.dart';

class MatchDetailScreen extends ConsumerWidget {
  final FootballMatch match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final predictions = ref.watch(predictionsProvider).valueOrNull ?? [];
    final label = '${match.homeTeam} - ${match.awayTeam}';
    final prediction = predictions
        .where((p) => p.matchLabel == label)
        .lastOrNull;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Text(
          match.leagueName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      floatingActionButton: match.canBet
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPredictionScreen(
                    initialMatchLabel:
                        '${match.homeTeam} - ${match.awayTeam}',
                    fixtureId: match.id,
                    kickoffUtc: match.kickoffUtc,
                    homeOdds: match.homeOdds,
                    drawOdds: match.drawOdds,
                    awayOdds: match.awayOdds,
                  ),
                ),
              ),
              icon: const Icon(Icons.star_rounded),
              label: _BetLabel(match: match),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          children: [
            // ── Carte équipes + score ──────────────────────────────────
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  children: [
                    _buildTeamsRow(context),
                    const SizedBox(height: 20),
                    _buildStatusChip(cs),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Cotes ─────────────────────────────────────────────────
            if (match.homeOdds != null &&
                match.drawOdds != null &&
                match.awayOdds != null)
              Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: _buildOddsSection(context, cs),
                ),
              ),
            // ── Mon pronostic ──────────────────────────────────────────
            if (prediction != null) ...[
              const SizedBox(height: 16),
              _PredictionSummary(prediction: prediction, cs: cs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasScore = match.status != 'scheduled' &&
        match.homeScore != null &&
        match.awayScore != null;

    return Row(
      children: [
        Expanded(child: _TeamBlock(name: match.homeTeam, cs: cs)),
        Column(
          children: [
            Text(
              hasScore
                  ? '${match.homeScore}  –  ${match.awayScore}'
                  : match.matchTime,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
                letterSpacing: hasScore ? 2 : 1,
              ),
            ),
            if (!hasScore) ...[
              const SizedBox(height: 4),
              Text(
                'Coup d\'envoi',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
            ],
          ],
        ),
        Expanded(child: _TeamBlock(name: match.awayTeam, cs: cs, isAway: true)),
      ],
    );
  }

  Widget _buildStatusChip(ColorScheme cs) {
    final (label, color) = switch (match.status) {
      'live' => ('⚡ En direct', Colors.green.shade600),
      'halftime' => ('Mi-temps', Colors.orange.shade600),
      'finished' => ('Terminé', Colors.grey.shade500),
      'postponed' => ('Reporté', Colors.red.shade500),
      'cancelled' => ('Annulé', Colors.red.shade500),
      _ => ('À venir', Colors.blue.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _buildOddsSection(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COTES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _OddsBlock(
                label: '1',
                sublabel: match.homeTeam.split(' ').first,
                value: match.homeOdds!,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OddsBlock(
                label: 'N',
                sublabel: 'Nul',
                value: match.drawOdds!,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OddsBlock(
                label: '2',
                sublabel: match.awayTeam.split(' ').first,
                value: match.awayOdds!,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Résumé du pronostic placé ─────────────────────────────────────────────────
class _PredictionSummary extends StatelessWidget {
  final Prediction prediction;
  final ColorScheme cs;
  const _PredictionSummary({required this.prediction, required this.cs});

  static Color _color(String s) => switch (s) {
        '1' => const Color(0xFF16A34A),
        'N' => const Color(0xFF6B7280),
        _ => const Color(0xFF2563EB),
      };

  static String _label(String s) => switch (s) {
        '1' => 'Victoire domicile',
        'N' => 'Match nul',
        _ => 'Victoire extérieure',
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(prediction.selection);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
              const SizedBox(width: 6),
              Text(
                'MON PRONOSTIC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(prediction.selection,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontSize: 18)),
                    Text(
                      '  ×${prediction.odds.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(_label(prediction.selection),
                  style: TextStyle(fontSize: 13, color: cs.outline)),
            ],
          ),
          // Confiance
          const SizedBox(height: 12),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < prediction.confidence
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: Colors.amber.shade500,
                ),
              ),
              const SizedBox(width: 6),
              Text('Confiance ${prediction.confidence}/5',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
          // Commentaire
          if (prediction.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${prediction.comment}"',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: cs.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bloc équipe ───────────────────────────────────────────────────────────────
class _TeamBlock extends StatelessWidget {
  final String name;
  final ColorScheme cs;
  final bool isAway;
  const _TeamBlock({required this.name, required this.cs, this.isAway = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant, width: 1.5),
          ),
          child: Center(
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Label du bouton parier avec compte à rebours si < 30 min ─────────────────
class _BetLabel extends StatelessWidget {
  final FootballMatch match;
  const _BetLabel({required this.match});

  @override
  Widget build(BuildContext context) {
    final until = match.timeUntilKickoff;
    if (until != null && until.inMinutes < 30) {
      final m = until.inMinutes;
      final s = until.inSeconds % 60;
      final label = m > 0 ? 'Parier ($m min)' : 'Parier ($s s)';
      return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
    }
    return const Text('Pronostiquer',
        style: TextStyle(fontWeight: FontWeight.w600));
  }
}

// ── Bloc cote ─────────────────────────────────────────────────────────────────
class _OddsBlock extends StatelessWidget {
  final String label;
  final String sublabel;
  final double value;
  final Color color;
  const _OddsBlock({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(sublabel,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.65)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
