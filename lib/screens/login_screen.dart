import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
      // authStateProvider détecte la connexion et redirige automatiquement
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Trop de tentatives. Réessaie plus tard.';
    }
    return 'Erreur de connexion. Vérifie ta connexion internet.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Logo / titre
                const Icon(Icons.sports_soccer, size: 72, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Matimatch',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connecte-toi pour accéder à tes pronostics',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mot de passe
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min. 6 caractères' : null,
                ),
                const SizedBox(height: 12),

                // Message d'erreur
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Bouton connexion
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Se connecter', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),

                // Lien vers inscription
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pas encore de compte ?'),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('S\'inscrire'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
