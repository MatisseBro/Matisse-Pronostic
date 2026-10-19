import 'package:flutter/foundation.dart';

/// Logger centralisé conforme Séance 12.
/// – Aucun log en Release (kReleaseMode guard).
/// – Masquage automatique des valeurs sensibles dans les messages.
class AppLogger {
  // Mots-clés déclenchant le masquage de la valeur associée.
  static const _sensitiveKeys = [
    'password',
    'pwd',
    'passwd',
    'token',
    'secret',
    'api_key',
    'apikey',
    'authorization',
    'bearer',
  ];

  /// Remplace les valeurs sensibles par *** dans [message].
  /// Méthode publique pour les tests unitaires.
  static String sanitize(String message) {
    var s = message;

    // Format JSON  "password":"valeur"  ou  "password": "valeur"
    s = s.replaceAllMapped(
      RegExp(
        '"(${_sensitiveKeys.join('|')})"'
        r'\s*:\s*"[^"]*"',
        caseSensitive: false,
      ),
      (m) => '"${m.group(1)!}":"***"',
    );

    // Bearer <token> dans les en-têtes HTTP
    s = s.replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer ***',
    );

    // Format .env / query-string  PASSWORD=valeur
    s = s.replaceAllMapped(
      RegExp(
        '(${_sensitiveKeys.join('|')})'
        r'\s*=\s*\S+',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)!}=***',
    );

    return s;
  }

  /// Log de débogage — silencieux en Release.
  static void d(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] ${sanitize(message)}');
  }

  /// Log d'information — silencieux en Release.
  static void i(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[I/$tag] ${sanitize(message)}');
  }

  /// Avertissement — silencieux en Release.
  static void w(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[W/$tag] ${sanitize(message)}');
  }

  /// Erreur — silencieux en Release (pas de fuite en prod).
  static void e(String tag, String message, [Object? error]) {
    if (kReleaseMode) return;
    final err = error != null ? ': $error' : '';
    debugPrint('[E/$tag] ${sanitize(message)}$err');
  }
}
