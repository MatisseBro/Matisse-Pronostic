import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logger/app_logger.dart';

/// Coffre-fort local conforme Séance 12 (flutter_secure_storage).
///
/// Stratégie de démonstration :
///   1. Lit d'abord le coffre chiffré (KeyStore Android / Keychain iOS).
///   2. Si le coffre est vide, retombe sur dotenv comme filet de sécurité.
///
/// En production, on supprimerait le fallback dotenv et on retirerait
/// `.env` des assets Flutter (pubspec.yaml).
class SecureVaultService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tag = 'VAULT';

  // ── Clés standard ──────────────────────────────────────────────────────────
  static const kMqttPassword = 'mqtt_password';
  static const kMqttUser     = 'mqtt_user';
  static const kApiFootball  = 'api_football_key';

  /// Lit une valeur depuis le coffre, avec repli sur dotenv si absente.
  /// Ne logue jamais la valeur — uniquement un booléen présence/absence.
  static Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) {
        AppLogger.d(_tag, 'read($key) → coffre ✓');
        return value;
      }
    } catch (e) {
      AppLogger.e(_tag, 'read($key) erreur coffre, repli dotenv', e);
    }
    // Repli sur dotenv (mode démo / premier démarrage)
    final envValue = dotenv.env[key.toUpperCase()];
    AppLogger.d(_tag, 'read($key) → dotenv ${envValue != null ? "✓" : "∅"}');
    return envValue;
  }

  /// Écrit une valeur dans le coffre chiffré.
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
    AppLogger.d(_tag, 'write($key) → ✓');
  }

  /// Supprime une clé du coffre.
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
    AppLogger.d(_tag, 'delete($key) → ✓');
  }

  /// Efface toutes les entrées du coffre (déconnexion / réinitialisation).
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
    AppLogger.d(_tag, 'deleteAll() → ✓');
  }

  /// Provisionne les secrets depuis dotenv vers le coffre (migration initiale).
  /// À appeler une seule fois, par exemple lors de la première connexion.
  static Future<void> provisionFromDotenv() async {
    final pairs = {
      kMqttPassword: dotenv.env['MQTT_PASSWORD'],
      kMqttUser:     dotenv.env['MQTT_USER'],
      kApiFootball:  dotenv.env['API_FOOTBALL_KEY'],
    };
    for (final entry in pairs.entries) {
      final v = entry.value;
      if (v != null && v.isNotEmpty) {
        final existing = await _storage.read(key: entry.key);
        if (existing == null || existing.isEmpty) {
          await _storage.write(key: entry.key, value: v);
          AppLogger.d(_tag, 'provision(${entry.key}) → ✓');
        }
      }
    }
  }
}
