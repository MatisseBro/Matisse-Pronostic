import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../viewmodels/predictions_view_model.dart';
import 'add_prediction_screen.dart';
import 'prediction_detail_screen.dart';

class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPredictions = ref.watch(predictionsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Text(
          'Mes pronostics',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddPredictionScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: asyncPredictions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (predictions) => predictions.isEmpty
            ? const _EmptyState()
            : _PredictionList(predictions: predictions),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_outline_rounded,
                size: 48, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text('Aucun pronostic pour le moment',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Appuie sur "Nouveau" pour en ajouter un',
              style: TextStyle(fontSize: 13, color: cs.outline)),
        ],
      ),
    );
  }
}

// ── Liste ─────────────────────────────────────────────────────────────────────
class _PredictionList extends StatelessWidget {
  final List<Prediction> predictions;
  const _PredictionList({required this.predictions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      itemCount: predictions.length,
      itemBuilder: (context, i) {
        final prediction = predictions[predictions.length - 1 - i];
        return _PredictionCard(prediction: prediction);
      },
    );
  }
}

// ── Carte d'un pronostic ──────────────────────────────────────────────────────
class _PredictionCard extends ConsumerWidget {
  final Prediction prediction;
  const _PredictionCard({required this.prediction});

  static Color _selectionColor(String s) => switch (s) {
        '1' => const Color(0xFF16A34A),
        'N' => const Color(0xFF6B7280),
        _ => const Color(0xFF2563EB),
      };

  static String _selectionLabel(String s) => switch (s) {
        '1' => 'Domicile',
        'N' => 'Nul',
        _ => 'Extérieur',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = _selectionColor(prediction.selection);
    final result = prediction.result;

    final borderColor = result == 'won'
        ? const Color(0xFF16A34A)
        : result == 'lost'
            ? cs.error
            : cs.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PredictionDetailScreen(prediction: prediction),
            ),
          ),
          child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: result != null ? 1.5 : 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Barre colorée gauche
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête match + résultat + supprimer
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                prediction.matchLabel,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (result != null)
                              _ResultBadge(result: result),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _confirmDelete(context, ref),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: cs.error, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Sélection + cote
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(prediction.selection,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                          fontSize: 16)),
                                  Text(
                                    '  ×${prediction.odds.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectionLabel(prediction.selection),
                              style: TextStyle(
                                  color: cs.outline, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Étoiles de confiance
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                              i < prediction.confidence
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 18,
                              color: Colors.amber.shade500,
                            )),
                            const SizedBox(width: 6),
                            Text('${prediction.confidence}/5',
                                style: TextStyle(
                                    fontSize: 12, color: cs.outline)),
                          ],
                        ),

                        // Commentaire
                        if (prediction.comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('"${prediction.comment}"',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: cs.outline)),
                        ],

                        const SizedBox(height: 12),
                        // ── Boutons résultat ─────────────────────────
                        _ResultButtons(
                          currentResult: result,
                          onSelect: (r) => ref
                              .read(predictionsProvider.notifier)
                              .setResult(prediction.id, r),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce pronostic ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(predictionsProvider.notifier).remove(prediction.id);
    }
  }
}

// ── Badge résultat ────────────────────────────────────────────────────────────
class _ResultBadge extends StatelessWidget {
  final String result;
  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final isWon = result == 'won';
    final color = isWon ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.error;
    final label = isWon ? '✓ Gagné' : '✗ Perdu';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Boutons pour marquer le résultat ─────────────────────────────────────────
class _ResultButtons extends StatelessWidget {
  final String? currentResult;
  final ValueChanged<String?> onSelect;
  const _ResultButtons({required this.currentResult, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Résultat :',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        _Btn(
          label: '✓ Gagné',
          active: currentResult == 'won',
          activeColor: const Color(0xFF16A34A),
          onTap: () => onSelect(currentResult == 'won' ? null : 'won'),
        ),
        const SizedBox(width: 6),
        _Btn(
          label: '✗ Perdu',
          active: currentResult == 'lost',
          activeColor: Theme.of(context).colorScheme.error,
          onTap: () => onSelect(currentResult == 'lost' ? null : 'lost'),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _Btn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? activeColor
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
