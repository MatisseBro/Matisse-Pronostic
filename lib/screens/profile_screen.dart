import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../services/auth_service.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/predictions_view_model.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull;
    final predictions = ref.watch(predictionsProvider).valueOrNull ?? [];

    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    final won = predictions.where((p) => p.result == 'won').length;
    final lost = predictions.where((p) => p.result == 'lost').length;
    final resolved = won + lost;
    final pending = predictions.length - resolved;
    final winRate = resolved == 0 ? null : (won / resolved * 100);

    // Bilan financier
    final totalInvested = predictions
        .where((p) => p.stake != null)
        .fold<double>(0, (sum, p) => sum + p.stake!);
    final totalRecovered = predictions
        .where((p) => p.result == 'won' && p.stake != null)
        .fold<double>(0, (sum, p) => sum + p.potentialGain!);
    final netBalance = predictions
        .where((p) => p.netProfit != null)
        .fold<double>(0, (sum, p) => sum + p.netProfit!);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: Text(
          'Profil',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Avatar + email ───────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(email,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Taux de réussite ─────────────────────────────────────────
          _SectionTitle('Taux de réussite'),
          const SizedBox(height: 10),
          _WinRateCard(
            winRate: winRate,
            won: won,
            lost: lost,
            pending: pending,
            cs: cs,
          ),
          const SizedBox(height: 24),

          // ── Bilan financier ──────────────────────────────────────────
          if (totalInvested > 0) ...[
            _SectionTitle('Bilan financier'),
            const SizedBox(height: 10),
            _FinanceCard(
              totalInvested: totalInvested,
              totalRecovered: totalRecovered,
              netBalance: netBalance,
              cs: cs,
            ),
            const SizedBox(height: 24),
          ],

          // ── Statistiques globales ────────────────────────────────────
          _SectionTitle('Statistiques'),
          const SizedBox(height: 10),
          _StatsCard(predictions: predictions, cs: cs),
          const SizedBox(height: 24),

          // ── Répartition 1 / N / 2 ────────────────────────────────────
          if (predictions.isNotEmpty) ...[
            _SectionTitle('Répartition des pronos'),
            const SizedBox(height: 10),
            _RepartitionCard(predictions: predictions, cs: cs),
            const SizedBox(height: 24),
          ],

          // ── Se déconnecter ───────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => AuthService.signOut(),
            icon: Icon(Icons.logout_rounded, color: cs.error),
            label: Text('Se déconnecter',
                style: TextStyle(
                    color: cs.error, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte taux de réussite ────────────────────────────────────────────────────
class _WinRateCard extends StatelessWidget {
  final double? winRate;
  final int won;
  final int lost;
  final int pending;
  final ColorScheme cs;
  const _WinRateCard({
    required this.winRate,
    required this.won,
    required this.lost,
    required this.pending,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = won + lost;
    final pct = winRate ?? 0.0;
    final color = pct >= 60
        ? const Color(0xFF16A34A)
        : pct >= 40
            ? Colors.amber.shade600
            : cs.error;

    return _Card(
      child: Column(
        children: [
          // Barre de progression circulaire simulée avec un LinearProgressIndicator
          Row(
            children: [
              // Grand pourcentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        winRate == null ? '--' : '${pct.round()}',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: winRate == null ? cs.outlineVariant : color,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      if (winRate != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('%',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    winRate == null
                        ? 'Aucun résultat renseigné'
                        : 'de réussite',
                    style: TextStyle(fontSize: 13, color: cs.outline),
                  ),
                ],
              ),
              const Spacer(),
              // Colonne de compteurs
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CountChip(
                      label: 'Gagné',
                      count: won,
                      color: const Color(0xFF16A34A)),
                  const SizedBox(height: 8),
                  _CountChip(label: 'Perdu', count: lost, color: cs.error),
                  const SizedBox(height: 8),
                  _CountChip(
                      label: 'En attente',
                      count: pending,
                      color: cs.outline),
                ],
              ),
            ],
          ),
          if (resolved > 0) ...[
            const SizedBox(height: 16),
            // Barre de progression won/lost
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (won > 0)
                      Expanded(
                        flex: won,
                        child: Container(color: const Color(0xFF16A34A)),
                      ),
                    if (lost > 0)
                      Expanded(
                        flex: lost,
                        child: Container(color: cs.error),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
      ],
    );
  }
}

// ── Statistiques globales ─────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final List<Prediction> predictions;
  final ColorScheme cs;
  const _StatsCard({required this.predictions, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = predictions.length;
    final avgConfidence = total == 0
        ? 0.0
        : predictions.map((p) => p.confidence).reduce((a, b) => a + b) /
            total;
    final favorite = _favoriteSelection(predictions);

    return _Card(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: '$total',
              label: 'Pronostics',
              icon: Icons.star_rounded,
              color: cs.primary,
            ),
          ),
          _VDivider(),
          Expanded(
            child: _StatItem(
              value: total == 0 ? '--' : avgConfidence.toStringAsFixed(1),
              label: 'Confiance moy.',
              icon: Icons.trending_up_rounded,
              color: Colors.amber.shade600,
            ),
          ),
          _VDivider(),
          Expanded(
            child: _StatItem(
              value: favorite,
              label: 'Favori',
              icon: Icons.emoji_events_rounded,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _favoriteSelection(List<Prediction> predictions) {
    if (predictions.isEmpty) return '--';
    final counts = <String, int>{'1': 0, 'N': 0, '2': 0};
    for (final p in predictions) {
      counts[p.selection] = (counts[p.selection] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

// ── Répartition 1/N/2 ────────────────────────────────────────────────────────
class _RepartitionCard extends StatelessWidget {
  final List<Prediction> predictions;
  final ColorScheme cs;
  const _RepartitionCard({required this.predictions, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = predictions.length;
    final count1 = predictions.where((p) => p.selection == '1').length;
    final countN = predictions.where((p) => p.selection == 'N').length;
    final count2 = predictions.where((p) => p.selection == '2').length;

    return _Card(
      child: Column(
        children: [
          _Bar(label: '1 – Domicile', count: count1, total: total,
              color: cs.primary),
          const SizedBox(height: 12),
          _Bar(label: 'N – Nul', count: countN, total: total,
              color: const Color(0xFF6B7280)),
          const SizedBox(height: 12),
          _Bar(label: '2 – Extérieur', count: count2, total: total,
              color: Colors.blue.shade600),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _Bar(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text('$count',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Bilan financier ───────────────────────────────────────────────────────────
class _FinanceCard extends StatelessWidget {
  final double totalInvested;
  final double totalRecovered;
  final double netBalance;
  final ColorScheme cs;
  const _FinanceCard({
    required this.totalInvested,
    required this.totalRecovered,
    required this.netBalance,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final netColor = netBalance > 0
        ? const Color(0xFF16A34A)
        : netBalance < 0
            ? cs.error
            : cs.outline;
    final netPrefix = netBalance > 0 ? '+' : '';

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FinItem(
                  label: 'Investi',
                  value: '${totalInvested.toStringAsFixed(2)} €',
                  color: cs.onSurface,
                ),
              ),
              Container(width: 1, height: 48, color: cs.outlineVariant),
              Expanded(
                child: _FinItem(
                  label: 'Récupéré',
                  value: '${totalRecovered.toStringAsFixed(2)} €',
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: netColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text('Bilan net',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '$netPrefix${netBalance.toStringAsFixed(2)} €',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: netColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: cs.primary),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatItem(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
