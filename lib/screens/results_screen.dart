import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../viewmodels/predictions_view_model.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _checking = false;

  Future<void> _autoCheck() async {
    setState(() => _checking = true);
    try {
      final count =
          await ref.read(predictionsProvider.notifier).autoCheckResults();
      if (mounted) {
        final msg = count == 0
            ? 'Aucun résultat disponible pour le moment'
            : '$count résultat${count > 1 ? 's' : ''} mis à jour';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final predictions = ref.watch(predictionsProvider).valueOrNull ?? [];

    // Tri : les plus récents d'abord
    final sorted = [...predictions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final won = sorted.where((p) => p.result == 'won').toList();
    final lost = sorted.where((p) => p.result == 'lost').toList();
    final pending = sorted.where((p) => p.result == null).toList();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Text(
          'Résultats',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          _checking
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Vérifier les résultats',
                  onPressed: _autoCheck,
                ),
        ],
      ),
      body: predictions.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
              children: [
                // ── Bannière auto-check ────────────────────────────────
                if (pending.any((p) => p.isPast))
                  _AutoCheckBanner(onCheck: _autoCheck, checking: _checking),

                // ── Gagnés ────────────────────────────────────────────
                if (won.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Gagnés',
                    count: won.length,
                    color: const Color(0xFF16A34A),
                    icon: Icons.check_circle_rounded,
                  ),
                  ...won.map((p) => _ResultCard(prediction: p)),
                  const SizedBox(height: 16),
                ],

                // ── Perdus ────────────────────────────────────────────
                if (lost.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Perdus',
                    count: lost.length,
                    color: cs.error,
                    icon: Icons.cancel_rounded,
                  ),
                  ...lost.map((p) => _ResultCard(prediction: p)),
                  const SizedBox(height: 16),
                ],

                // ── En attente ────────────────────────────────────────
                if (pending.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'En attente',
                    count: pending.length,
                    color: cs.outline,
                    icon: Icons.hourglass_top_rounded,
                  ),
                  ...pending.map((p) => _ResultCard(prediction: p)),
                ],
              ],
            ),
    );
  }
}

// ── Bannière suggérant la vérification automatique ────────────────────────────
class _AutoCheckBanner extends StatelessWidget {
  final VoidCallback onCheck;
  final bool checking;
  const _AutoCheckBanner({required this.onCheck, required this.checking});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Des matchs sont terminés — vérifier les résultats',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: checking ? null : onCheck,
            child: Text('Vérifier',
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── En-tête de section ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte résultat ────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Prediction prediction;
  const _ResultCard({required this.prediction});

  static Color _selColor(String s) => switch (s) {
        '1' => const Color(0xFF16A34A),
        'N' => const Color(0xFF6B7280),
        _ => const Color(0xFF2563EB),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selColor = _selColor(prediction.selection);
    final result = prediction.result;

    final borderColor = result == 'won'
        ? const Color(0xFF16A34A)
        : result == 'lost'
            ? cs.error
            : cs.outlineVariant;

    final resultIcon = result == 'won'
        ? Icons.check_circle_rounded
        : result == 'lost'
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;

    final resultColor = result == 'won'
        ? const Color(0xFF16A34A)
        : result == 'lost'
            ? cs.error
            : cs.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: borderColor, width: result != null ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barre colorée gauche
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: selColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contenu principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction.matchLabel,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  decoration: BoxDecoration(
                                    color: selColor.withValues(
                                        alpha: 0.10),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: selColor.withValues(
                                            alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '${prediction.selection}  ×${prediction.odds.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: selColor,
                                        fontSize: 13),
                                  ),
                                ),
                                if (prediction.stake != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mise: ${prediction.stake!.toStringAsFixed(0)}€',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.outline),
                                  ),
                                ],
                              ],
                            ),
                            if (prediction.result != null &&
                                prediction.stake != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                prediction.result == 'won'
                                    ? '+${prediction.netProfit!.toStringAsFixed(2)} €'
                                    : '${prediction.netProfit!.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: resultColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Icône résultat
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(resultIcon,
                              size: 28, color: resultColor),
                          const SizedBox(height: 4),
                          Text(
                            result == 'won'
                                ? 'Gagné'
                                : result == 'lost'
                                    ? 'Perdu'
                                    : 'En attente',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: resultColor),
                          ),
                        ],
                      ),
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
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events_outlined,
                size: 48, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text('Aucun pronostic encore',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Tes résultats apparaîtront ici',
              style: TextStyle(fontSize: 13, color: cs.outline)),
        ],
      ),
    );
  }
}
