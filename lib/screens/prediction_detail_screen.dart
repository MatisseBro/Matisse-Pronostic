import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../viewmodels/predictions_view_model.dart';

class PredictionDetailScreen extends ConsumerWidget {
  final Prediction prediction;
  const PredictionDetailScreen({super.key, required this.prediction});

  static Color _color(String s) => switch (s) {
        '1' => const Color(0xFF16A34A),
        'N' => const Color(0xFF6B7280),
        _ => const Color(0xFF2563EB),
      };

  static String _selectionLabel(String s) => switch (s) {
        '1' => 'Victoire domicile',
        'N' => 'Match nul',
        _ => 'Victoire extérieure',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(prediction.selection);

    // Écoute les changements en temps réel (résultat peut changer)
    final current = ref.watch(predictionsProvider).valueOrNull
        ?.where((p) => p.id == prediction.id)
        .firstOrNull ?? prediction;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Text('Détail du pronostic',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Match ────────────────────────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('MATCH'),
                const SizedBox(height: 8),
                Text(
                  current.matchLabel,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(current.createdAt),
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Sélection + cote ─────────────────────────────────────────
          _Card(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(current.selection,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: color)),
                      Text('×${current.odds.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectionLabel(current.selection),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < current.confidence
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: Colors.amber.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Mise + gains ──────────────────────────────────────────────
          if (current.stake != null)
            _Card(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FinanceItem(
                        label: 'Mise',
                        value: '${current.stake!.toStringAsFixed(2)} €',
                        color: cs.onSurface,
                      ),
                      _FinanceItem(
                        label: 'Gain potentiel',
                        value:
                            '${current.potentialGain!.toStringAsFixed(2)} €',
                        color: cs.primary,
                      ),
                      if (current.result == 'won')
                        _FinanceItem(
                          label: 'Profit net',
                          value:
                              '+${current.netProfit!.toStringAsFixed(2)} €',
                          color: const Color(0xFF16A34A),
                        ),
                      if (current.result == 'lost')
                        _FinanceItem(
                          label: 'Perte',
                          value:
                              '${current.netProfit!.toStringAsFixed(2)} €',
                          color: cs.error,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (current.stake != null) const SizedBox(height: 12),

          // ── Commentaire ───────────────────────────────────────────────
          if (current.comment.isNotEmpty) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('COMMENTAIRE'),
                  const SizedBox(height: 8),
                  Text(
                    '"${current.comment}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Résultat ──────────────────────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('RÉSULTAT'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ResultButton(
                        label: '✓ Gagné',
                        active: current.result == 'won',
                        activeColor: const Color(0xFF16A34A),
                        onTap: () => ref
                            .read(predictionsProvider.notifier)
                            .setResult(
                              current.id,
                              current.result == 'won' ? null : 'won',
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResultButton(
                        label: '✗ Perdu',
                        active: current.result == 'lost',
                        activeColor: cs.error,
                        onTap: () => ref
                            .read(predictionsProvider.notifier)
                            .setResult(
                              current.id,
                              current.result == 'lost' ? null : 'lost',
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${d.day} ${months[d.month - 1]}. ${d.year}';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.primary));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FinanceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _ResultButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ResultButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? activeColor : cs.outline)),
      ),
    );
  }
}
