import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend_request.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/social_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _emailCtrl = TextEditingController();
  UserProfile? _foundUser;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() { _searching = true; _foundUser = null; _searchError = null; });

    try {
      final found = await UserService.findByEmail(email);
      final myUid = ref.read(authStateProvider).valueOrNull?.uid;
      if (!mounted) return;

      if (found == null) {
        setState(() { _searchError = 'Aucun utilisateur trouvé pour "$email".'; });
      } else if (found.uid == myUid) {
        setState(() { _searchError = 'Vous ne pouvez pas vous ajouter vous-même.'; });
      } else {
        setState(() { _foundUser = found; });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(UserProfile target) async {
    final myProfile = ref.read(currentUserProfileProvider).valueOrNull;
    if (myProfile == null) return;

    try {
      await SocialService.sendFriendRequest(myProfile, target);
      if (!mounted) return;
      setState(() { _foundUser = null; _emailCtrl.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande envoyée à ${target.displayName} !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    var myProfile = ref.read(currentUserProfileProvider).valueOrNull;
    if (myProfile == null) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) myProfile = await UserService.getProfile(uid);
    }
    if (myProfile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil non disponible. Réessaie dans un instant.'),
        ));
      }
      return;
    }
    try {
      await SocialService.acceptFriendRequest(myProfile, request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.fromName} ajouté(e) comme ami(e) !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _declineRequest(FriendRequest request) async {
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (myUid == null) return;
    try {
      await SocialService.declineFriendRequest(myUid, request.fromUid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final friends  = ref.watch(friendsProvider).valueOrNull ?? [];
    final requests = ref.watch(friendRequestsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Text('Mes amis',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── Ajouter un ami ────────────────────────────────────────────────
          _SectionTitle('Ajouter un ami'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'Email de l\'ami',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: cs.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _searching ? null : _search,
                      child: _searching
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Chercher'),
                    ),
                  ],
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 10),
                  Text(_searchError!,
                      style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                if (_foundUser != null) ...[
                  const SizedBox(height: 14),
                  _UserTile(
                    profile: _foundUser!,
                    trailing: FilledButton.icon(
                      onPressed: () => _sendRequest(_foundUser!),
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Demande'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Demandes reçues ───────────────────────────────────────────────
          if (requests.isNotEmpty) ...[
            _SectionTitle('Demandes reçues (${requests.length})'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: requests.asMap().entries.map((entry) {
                  final i = entry.key;
                  final req = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: cs.secondaryContainer,
                          child: Text(
                            req.fromName.isNotEmpty
                                ? req.fromName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onSecondaryContainer),
                          ),
                        ),
                        title: Text(req.fromName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: Text(req.fromEmail,
                            style: TextStyle(fontSize: 12, color: cs.outline)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check_circle_outline_rounded,
                                  color: cs.primary, size: 22),
                              tooltip: 'Accepter',
                              onPressed: () => _acceptRequest(req),
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel_outlined,
                                  color: cs.error, size: 22),
                              tooltip: 'Refuser',
                              onPressed: () => _declineRequest(req),
                            ),
                          ],
                        ),
                      ),
                      if (i < requests.length - 1)
                        Divider(height: 1, indent: 56, color: cs.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Liste des amis ────────────────────────────────────────────────
          _SectionTitle('Amis (${friends.length})'),
          const SizedBox(height: 10),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Aucun ami pour le moment.',
                    style: TextStyle(color: cs.outline, fontSize: 14)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: friends.asMap().entries.map((entry) {
                  final i = entry.key;
                  final friend = entry.value;
                  return Column(
                    children: [
                      _UserTile(
                        profile: friend,
                        trailing: IconButton(
                          icon: Icon(Icons.person_remove_outlined,
                              color: cs.error, size: 20),
                          tooltip: 'Retirer',
                          onPressed: () => _confirmRemove(friend),
                        ),
                      ),
                      if (i < friends.length - 1)
                        Divider(height: 1, indent: 56, color: cs.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(UserProfile friend) async {
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (myUid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${friend.displayName} ?'),
        content: const Text('L\'amitié sera supprimée des deux côtés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await SocialService.removeFriend(myUid, friend.uid);
    }
  }
}

// ── Tuile utilisateur réutilisable ────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final UserProfile profile;
  final Widget? trailing;
  const _UserTile({required this.profile, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(profile.initial,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
                fontSize: 16)),
      ),
      title: Text(profile.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(profile.email,
          style: TextStyle(fontSize: 12, color: cs.outline)),
      trailing: trailing,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.primary));
  }
}
