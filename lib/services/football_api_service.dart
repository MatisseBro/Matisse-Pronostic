import 'package:flutter_dotenv/flutter_dotenv.dart';

class FootballApiService {
  static const String _baseUrl = 'https://v3.football.api-sports.io';

  // Lit la clé API depuis le fichier .env
  static String get _apiKey => dotenv.env['API_FOOTBALL_KEY'] ?? '';

  // Headers à envoyer avec chaque requête vers API-Football
  static Map<String, String> get headers => {
    'x-rapidapi-key': _apiKey,
    'x-rapidapi-host': 'v3.football.api-sports.io',
  };

  static String get baseUrl => _baseUrl;
}
