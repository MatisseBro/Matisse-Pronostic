import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/predictions_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Text('Paramètres',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Général ──────────────────────────────────────────────────
          _SectionHeader('Général'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Version de l\'application',
            trailing: Text('1.0.0',
                style: TextStyle(color: cs.outline, fontSize: 14)),
          ),

          const SizedBox(height: 24),

          // ── Données ───────────────────────────────────────────────────
          _SectionHeader('Données'),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            iconColor: cs.error,
            title: 'Réinitialiser tous les pronostics',
            titleColor: cs.error,
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Tout effacer ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Tous tes pronostics seront supprimés définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(predictionsProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pronostics supprimés'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: iconColor ?? cs.onSurfaceVariant),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: titleColor ?? cs.onSurface)),
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right_rounded,
                    color: cs.outlineVariant)
                : null),
        onTap: onTap,
      ),
    );
  }
}
